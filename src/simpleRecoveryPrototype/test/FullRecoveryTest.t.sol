// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ModuleKitHelpers} from "modulekit/ModuleKit.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {BaseTest} from "./SimpleRecoveryBaseTest.t.sol";
import {EmailAuthMsg, EmailProof} from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import {MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR} from "modulekit/accounts/common/interfaces/IERC7579Module.sol";

// @notice Test contract for recovery functionality that extends BaseTest
// @dev Tests the full recovery process including EOA and email-based guardian acceptance
contract RecoveryTest is BaseTest {
    using Strings for uint256;
    string private constant NAME    = "EOAGuardianVerifier";
    string private constant VERSION = "1.0.0";

    /// @dev EIP-712 Domain typehash:
    /// keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
    bytes32 private constant EIP712_DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );

    /// @dev Sample typed struct typehash:
    /// keccak256("GuardianAcceptance(address recoveredAccount,uint256 templateIdx,bytes32 commandParamsHash)")
    bytes32 private constant GUARDIAN_TYPEHASH = keccak256(
        "GuardianAcceptance(address recoveredAccount,uint256 templateIdx,bytes32 commandParamsHash)"
    );

    string public recoveryDataHashString;
    bytes[] public commandParams;

    // @notice Sets up the test environment by installing necessary modules
    // @dev Installs validator and executor modules with required configurations
    function setUp() public override {
        super.setUp();

        bytes memory isInstalledContext = ""; 
        bytes memory data = abi.encode(
            isInstalledContext, 
            guardians, 
            weights, 
            guardianTypes, 
            threshold, 
            delay,
            expiry 
        );

        vm.prank(owner1);

        ModuleKitHelpers.installModule({
            instance: instance2,
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: accountAddress1,
            data: abi.encode(owner1)
        });
        ModuleKitHelpers.installModule({
            instance: instance2,
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: address(recoveryModule),
            data: data
        });
    }

    // @notice Tests the complete recovery process
    // @dev Includes EOA guardian acceptance, email guardian acceptance, and recovery completion
    // The function tests:
    // 1. EOA guardian acceptance with signature verification
    // 2. Email guardian acceptance with proof verification
    // 3. Recovery process initiation
    // 4. Recovery completion and ownership transfer
    function testFullRecoveryProcess() public {
        uint256 templateId = uint256(keccak256(abi.encode(1, "ACCEPTANCE", 0)));
        bytes32 nullifier = bytes32(uint256(1));
       
        bytes[] memory acceptanceParams = new bytes[](1);
        acceptanceParams[0] = abi.encode(owner1);
      
        {
             uint256 privateKey1 = uint256(
            keccak256(abi.encodePacked("eoaGuardian1"))
        );
            bytes memory encodedParams = abi.encode(acceptanceParams);
           
            bytes32 commandParamsHash = keccak256(encodedParams);
            
            uint256 templateIdx = 0;

            bytes32 structHash = keccak256(
                abi.encode(
                    GUARDIAN_TYPEHASH,
                      owner1, 
                    templateIdx,
                    commandParamsHash
                )
            );
           
              bytes32 domainSeparator = recoveryModule.getDomainSeparator(); 
   
            bytes32 digest = keccak256(
                abi.encodePacked("\x19\x01", domainSeparator, structHash)
               );
           
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(
    privateKey1,
    digest);

    bytes memory signature = abi.encodePacked(r, s, v);

            vm.prank(eoaGuardian1);
            recoveryModule.handleEOAAcceptance(templateIdx,acceptanceParams, signature);
        }
         
        {
        string memory exactCommand = string(
            abi.encodePacked(
                "Accept guardian request for ",
                Strings.toHexString(uint160(owner1))
            )
        ); 
              EmailProof memory proof1 = generateMockEmailProof(
             exactCommand,
      
            nullifier,
            accountSalts[1]
        );
       
        EmailAuthMsg memory emailAuthMsg1 = EmailAuthMsg({
                templateId: templateId,
                commandParams: acceptanceParams,
                skippedCommandPrefix: 0,
                proof: proof1
            });
            vm.prank(emailGuardian1);
            recoveryModule.handleEmailAuthAcceptance(emailAuthMsg1, 0);
        }

        vm.prank(eoaGuardian1);

        commandParams = new bytes[](2);
        commandParams[0] = abi.encode(owner1);
        recoveryDataHashString = uint256(recoveryDataHash).toHexString(32);
        commandParams[1] = abi.encode(recoveryDataHashString);

        recoveryModule.testProcessRecovery(eoaGuardian1, 0, commandParams);
        vm.prank(emailGuardian1);
        recoveryModule.testProcessRecovery(emailGuardian1, 0, commandParams);

        (uint256 executeAfter, , , ) = recoveryModule.getRecoveryRequest(
            owner1
        );

        vm.warp(executeAfter + 1);

        recoveryCallData = abi.encodeWithSelector(
            RECOVERY_SELECTOR,
            newOwner 
        );
        bytes memory recoveryData1 = abi.encode(
            accountAddress1,
            recoveryCallData 
        );

        vm.prank(address(0x123));
        recoveryModule.completeRecovery(owner1, recoveryData1);

        address newOwnerAccount = validator.owners(owner1);
        assertEq(
            newOwnerAccount,
            newOwner,
            "Recovery did not set the new owner correctly"
        );

        emit log("Recovery completed successfully");
    }
}