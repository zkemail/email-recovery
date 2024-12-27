// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/simple-recovery-module/SimpleRecoveryModule.sol";

// Mock contracts for the dependencies
contract MockVerifier is IVerifier {
    function commandBytes() external pure override returns (uint256) {
        return 123;
    }

    function verifyEmailProof(EmailProof calldata) external pure override returns (bool) {
        return true;
    }
}

contract MockDKIMRegistry is IDKIMRegistry {
    function isDKIMPublicKeyHashValid(
        string memory,
        bytes32
    )
        external
        pure
        override
        returns (bool)
    {
        return true;
    }
}

contract MockAccount is IERC7579Account {
    address public owner;

    function changeOwner(address newOwner) external override {
        owner = newOwner;
    }
}

contract SimpleRecoveryModuleTest is Test {
    SimpleRecoveryModule module;
    MockVerifier verifier;
    MockDKIMRegistry dkimRegistry;
    MockAccount mockAccount;

    address owner = address(0x1);
    address guardian = address(0x2);
    address newOwner = address(0x3);
    address nonGuardian = address(0x4);

    function setUp() public {
        verifier = new MockVerifier();
        dkimRegistry = new MockDKIMRegistry();
        module = new SimpleRecoveryModule(address(verifier), address(dkimRegistry));
        mockAccount = new MockAccount();
        
        // Initialize timestamp to avoid underflow
        vm.warp(block.timestamp + 2 hours);
    }

    function testSetupGuardian() public {
        vm.prank(owner);
        module.setupGuardian(guardian);
        assertEq(module.accountGuardians(owner), guardian, "Guardian should be set correctly");
        assertEq(module.accountOwners(owner), owner, "Owner should be set correctly");
    }

    function testCannotSetGuardianTwice() public {
        vm.prank(owner);
        module.setupGuardian(guardian);

        vm.prank(owner);
        vm.expectRevert(SimpleRecoveryModule.SimpleRecoveryModule__GuardianAlreadySet.selector);
        module.setupGuardian(guardian);
    }

    function testRecoverByGuardian() public {
        // Setup the account and guardian first
        vm.startPrank(address(mockAccount));
        module.setupGuardian(guardian);
        vm.stopPrank();

        // Perform recovery by guardian
        vm.prank(guardian);
        module.recoverByGuardian(address(mockAccount), newOwner);

        assertEq(mockAccount.owner(), newOwner, "Owner should be updated to newOwner");
        assertEq(module.accountOwners(address(mockAccount)), newOwner, "Account owner mapping should be updated");
    }

    function testCannotRecoverByNonGuardian() public {
        // Setup the account and guardian first
        vm.startPrank(address(mockAccount));
        module.setupGuardian(guardian);
        vm.stopPrank();

        vm.prank(nonGuardian);
        vm.expectRevert(SimpleRecoveryModule.SimpleRecoveryModule__InvalidGuardian.selector);
        module.recoverByGuardian(address(mockAccount), newOwner);
    }

    function testRecoverByEmail() public {
        uint256 currentTime = block.timestamp;
        
        EmailProof memory emailProof = EmailProof({
            domainName: "example.com",
            publicKeyHash: keccak256("public_key"),
            timestamp: currentTime,
            maskedCommand: "recovery",
            emailNullifier: keccak256("nullifier"),
            accountSalt: keccak256("salt"),
            isCodeExist: true,
            proof: bytes("dummy_proof")
        });

        // Perform recovery by email
        module.recoverByEmail(address(mockAccount), newOwner, emailProof);

        assertEq(mockAccount.owner(), newOwner, "Owner should be updated to newOwner");
        assertEq(module.accountOwners(address(mockAccount)), newOwner, "Account owner mapping should be updated");
        assertEq(module.accountNullifiers(address(mockAccount)), emailProof.emailNullifier, "Nullifier should be stored");
    }

    function testCannotRecoverWithInvalidNullifier() public {
        uint256 currentTime = block.timestamp;
        
        EmailProof memory emailProof = EmailProof({
            domainName: "example.com",
            publicKeyHash: keccak256("public_key"),
            timestamp: currentTime,
            maskedCommand: "recovery",
            emailNullifier: keccak256("nullifier"),
            accountSalt: keccak256("salt"),
            isCodeExist: true,
            proof: bytes("dummy_proof")
        });

        // Perform first recovery
        module.recoverByEmail(address(mockAccount), newOwner, emailProof);

        // Try to recover again with the same nullifier
        vm.expectRevert(SimpleRecoveryModule.SimpleRecoveryModule__NullifierIsUsed.selector);
        module.recoverByEmail(address(mockAccount), newOwner, emailProof);
    }

    function testCannotRecoverWithExpiredProof() public {
        // Set a base timestamp
        uint256 currentTime = block.timestamp;
        
        // Create the email proof with an expired timestamp
        EmailProof memory emailProof = EmailProof({
            domainName: "example.com",
            publicKeyHash: keccak256("public_key"),
            timestamp: currentTime - 2 hours,  // 2 hours old, which exceeds the 1 hour limit
            maskedCommand: "recovery",
            emailNullifier: keccak256("nullifier"),
            accountSalt: keccak256("salt"),
            isCodeExist: true,
            proof: bytes("dummy_proof")
        });

        vm.expectRevert(SimpleRecoveryModule.SimpleRecoveryModule__InvalidProof.selector);
        module.recoverByEmail(address(mockAccount), newOwner, emailProof);
    }
}