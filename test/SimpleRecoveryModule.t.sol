// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import "../src/recovery-module-prototype/SimpleRecoveryModule.sol";

contract MockAccount {
    address public owner;
    
    function changeOwner(address newOwner) external {
        owner = newOwner;
    }
}

contract MockVerifier {
    function commandBytes() external pure returns (uint256) {
        return 32;
    }
    
    function verifyEmailProof(EmailProof calldata) external pure returns (bool) {
        return true;
    }
}

contract MockDKIMRegistry {
    function isDKIMPublicKeyHashValid(
        string memory,
        bytes32
    ) external pure returns (bool) {
        return true;
    }
}

contract SimpleRecoveryModuleTest is Test {
    SimpleRecoveryModule public module;
    MockAccount public account;
    MockVerifier public verifier;
    MockDKIMRegistry public dkimRegistry;
    
    address guardian = address(0x123);
    address newOwner = address(0x456);
    
    function setUp() public {
        verifier = new MockVerifier();
        dkimRegistry = new MockDKIMRegistry();
        module = new SimpleRecoveryModule(address(verifier), address(dkimRegistry));
        account = new MockAccount();
        
        // Setup recovery parameters
        vm.prank(address(account));
        module.setupGuardian(guardian);
    }
    
    function testRecoverByGuardian() public {
        // Perform recovery using guardian
        vm.prank(guardian);
        module.recoverByGuardian(address(account), newOwner);
        
        // Verify owner was changed
        assertEq(account.owner(), newOwner);
        assertEq(module.accountOwners(address(account)), newOwner);
    }
    
    function testRecoverByEmail() public {
        EmailProof memory proof = EmailProof({
            domainName: "example.com",
            publicKeyHash: bytes32(uint256(1)),
            timestamp: block.timestamp,
            maskedCommand: "recover",
            emailNullifier: bytes32(uint256(2)),
            accountSalt: bytes32(uint256(3)),
            isCodeExist: true,
            proof: new bytes(0)
        });
        
        module.recoverByEmail(address(account), newOwner, proof);
        
        // Verify owner was changed
        assertEq(account.owner(), newOwner);
        assertEq(module.accountOwners(address(account)), newOwner);
    }
}