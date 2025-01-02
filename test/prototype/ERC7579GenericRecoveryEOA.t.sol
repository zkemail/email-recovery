// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Test, Vm, console } from "forge-std/Test.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/external/ERC7579.sol";
import { ModuleKitHelpers, ModuleKitUserOp } from "modulekit/ModuleKit.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import {ERC7579GenericRecoveryBase} from "./ERC7579GenericRecoveryBase.t.sol";
import {ECDSAGuardianVerifier} from "../../src/prototype/verifiers/EDCSAGuardianVerifier.sol";
import { IGuardianVerifier, Guardian } from "../../src/prototype/interfaces/IGuardianVerifier.sol";

contract ERC7579GenericRecoveryEOA is ERC7579GenericRecoveryBase {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    address public guardianVerifier;

    function setUp() public override {
        super.setUp();
        guardianVerifier = address(1);

    
        Guardian[] memory _guardians1 = new Guardian[](3);
        _guardians1[0] = Guardian(abi.encode(guardians1[0].addr), guardianVerifier);
        _guardians1[1] = Guardian(abi.encode(guardians1[1].addr), guardianVerifier);
        _guardians1[2] = Guardian(abi.encode(guardians1[2].addr), guardianVerifier);

        bytes memory recoveryModuleInstallData1 =
            abi.encode(isInstalledContext, _guardians1, guardianWeights, threshold, delay, expiry);

        vm.startPrank(accountAddress1);
        genericRecoveryModule.addSupportForGuardianVerifier(guardianVerifier);
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

    function test_RecoveryEOA1() public {
        assert(validator.owners(accountAddress1) == owner1);

        vm.startPrank(guardians1[0].addr);
        genericRecoveryModule.acceptGuardian(
            accountAddress1,
            abi.encode(guardians1[0].addr),
            ""
        );
        vm.stopPrank();

        vm.startPrank(guardians1[1].addr);
        genericRecoveryModule.acceptGuardian(
            accountAddress1,
            abi.encode(guardians1[1].addr),
            ""
        );
        vm.stopPrank();

        vm.startPrank(guardians1[2].addr);
        genericRecoveryModule.acceptGuardian(
            accountAddress1,
            abi.encode(guardians1[2].addr),
            ""
        );
        vm.stopPrank();

        vm.startPrank(guardians1[0].addr);
        genericRecoveryModule.processRecovery(
            accountAddress1,
            abi.encode(guardians1[0].addr), 
            abi.encode(recoveryDataHash1)
        );
        vm.stopPrank();

        vm.startPrank(guardians1[1].addr);
        genericRecoveryModule.processRecovery(
            accountAddress1,
            abi.encode(guardians1[1].addr), 
            abi.encode(recoveryDataHash1)
        );
        vm.stopPrank();

        vm.startPrank(guardians1[2].addr);
        genericRecoveryModule.processRecovery(
            accountAddress1,
            abi.encode(guardians1[2].addr), 
            abi.encode(recoveryDataHash1)
        );
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);

        genericRecoveryModule.completeRecovery(accountAddress1, recoveryData1);

        assert(validator.owners(accountAddress1) == newOwner1);
    }
}