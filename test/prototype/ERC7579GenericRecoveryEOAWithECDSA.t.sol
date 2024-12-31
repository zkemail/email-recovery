// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Test, Vm, console } from "forge-std/Test.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/external/ERC7579.sol";
import { ModuleKitHelpers, ModuleKitUserOp } from "modulekit/ModuleKit.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import {ERC7579GenericRecoveryBase} from "./ERC7579GenericRecoveryBase.t.sol";
import {ECDSAGuardianVerifier} from "../../src/prototype/verifiers/EDCSAGuardianVerifier.sol";
import { IGuardianVerifier, Guardian } from "../../src/prototype/interfaces/IGuardianVerifier.sol";

contract ERC7579GenericRecoveryEOAWithECDSA is ERC7579GenericRecoveryBase {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    ECDSAGuardianVerifier public guardianVerifier1;
    address public guardianVerifier2;

    function setUp() public override {
        super.setUp();
        guardianVerifier1 = new ECDSAGuardianVerifier();
        guardianVerifier2 = address(1);

    
        Guardian[] memory _guardians1 = new Guardian[](3);
        _guardians1[0] = Guardian(abi.encode(guardians1[0].addr), address(guardianVerifier1));
        _guardians1[1] = Guardian(abi.encode(guardians1[1].addr), address(guardianVerifier2));
        _guardians1[2] = Guardian(abi.encode(guardians1[2].addr), address(guardianVerifier1));

        bytes memory recoveryModuleInstallData1 =
            abi.encode(isInstalledContext, _guardians1, guardianWeights, threshold, delay, expiry);

        vm.startPrank(accountAddress1);
        genericRecoveryModule.addSupportForGuardianVerifier(address(guardianVerifier1));
        genericRecoveryModule.addSupportForGuardianVerifier(guardianVerifier2);
        vm.stopPrank();

        // Install modules for account 1
        instance1.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: validatorAddress,
            data: abi.encode(owner1)
        });
        instance1.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: address(genericRecoveryModule),
            data: recoveryModuleInstallData1
        });
    }

    function mockAcceptGuardianDigest(address account, uint64 nonce) internal returns(bytes32){
        bytes32 _HANDLE_TYPEHASH = keccak256("HandleMessage(bytes32 hash, uint256 nonce)");
        bytes32 acceptanceMsgHash = keccak256(
            bytes(string.concat("Accept Guardian for account: ", Strings.toHexString(uint256(uint160(account)), 20), " using ", Strings.toHexString(uint256(uint160(address(genericRecoveryModule))), 20)))
        );
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                guardianVerifier1.domainSeparator(),
                keccak256(abi.encode(_HANDLE_TYPEHASH, acceptanceMsgHash, nonce))
            )
        );
        return digest;
    }

    function mockProcessRecoveryDigest(bytes32 recoveryHash, uint64 nonce) internal returns(bytes32){
        bytes32 _HANDLE_TYPEHASH = keccak256("HandleMessage(bytes32 hash, uint256 nonce)");
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                guardianVerifier1.domainSeparator(),
                keccak256(abi.encode(_HANDLE_TYPEHASH, recoveryHash, nonce))
            )
        );
        return digest;
    }

    function test_RecoveryEOAWithECDSA1() public {
        assert(validator.owners(accountAddress1) == owner1);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(guardians1[0], mockAcceptGuardianDigest(accountAddress1, 0));
        bytes memory signature1 = abi.encodePacked(r, s, v);
        genericRecoveryModule.acceptGuardian(
            accountAddress1,
            abi.encode(guardians1[0].addr), 
            signature1
        );

        vm.startPrank(guardians1[1].addr);
        genericRecoveryModule.acceptGuardian(
            accountAddress1,
            abi.encode(guardians1[1].addr),
            ""
        );
        vm.stopPrank();

        (v, r, s) = vm.sign(guardians1[2], mockAcceptGuardianDigest(accountAddress1, 0));
        bytes memory signature3 = abi.encodePacked(r, s, v);
        genericRecoveryModule.acceptGuardian(
            accountAddress1,
            abi.encode(guardians1[2].addr), 
            signature3
        );

        (v, r, s) = vm.sign(guardians1[0], mockProcessRecoveryDigest(recoveryDataHash1, 1));
        signature1 = abi.encodePacked(r, s, v);
        genericRecoveryModule.processRecovery(
            accountAddress1,
            abi.encode(guardians1[0].addr), 
            abi.encode(recoveryDataHash1, signature1)
        );

        vm.startPrank(guardians1[1].addr);
        genericRecoveryModule.processRecovery(
            accountAddress1,
            abi.encode(guardians1[1].addr), 
            abi.encode(recoveryDataHash1)
        );
        vm.stopPrank();

        (v, r, s) = vm.sign(guardians1[2], mockProcessRecoveryDigest(recoveryDataHash1, 1));
        signature3 = abi.encodePacked(r, s, v);
        genericRecoveryModule.processRecovery(
            accountAddress1,
            abi.encode(guardians1[2].addr), 
            abi.encode(recoveryDataHash1, signature3)
        );

        vm.warp(block.timestamp + 1 days);

        genericRecoveryModule.completeRecovery(accountAddress1, recoveryData1);

        assert(validator.owners(accountAddress1) == newOwner1);
    }
}