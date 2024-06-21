// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { UnitBase } from "../UnitBase.t.sol";
import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { EmailRecoveryManager } from "src/EmailRecoveryManager.sol";

contract EmailRecoveryManager_initialize_Test is UnitBase {
    EmailRecoveryManager manager;

    function setUp() public override {
        super.setUp();

        vm.startPrank(accountAddress);
        manager = new EmailRecoveryManager(
            address(verifier),
            address(dkimRegistry),
            address(emailAuthImpl),
            address(emailRecoveryHandler)
        );
        vm.stopPrank();
    }

    function test_Initialize_RevertWhen_InitializerNotDeployer() public {
        vm.expectRevert(IEmailRecoveryManager.InitializerNotDeployer.selector);
        manager.initialize(recoveryModuleAddress);
    }

    function test_Initialize_RevertWhen_InvalidRecoveryModule() public {
        address invalidRecoveryModule = address(0);

        vm.startPrank(accountAddress);
        vm.expectRevert(IEmailRecoveryManager.InvalidRecoveryModule.selector);
        manager.initialize(invalidRecoveryModule);
    }

    function test_Initialize_RevertWhen_CalledMoreThanOnce() public {
        vm.startPrank(accountAddress);
        manager.initialize(recoveryModuleAddress);

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        manager.initialize(recoveryModuleAddress);
    }

    function test_Initialize_Succeeds() public {
        vm.startPrank(accountAddress);
        manager.initialize(recoveryModuleAddress);

        assertEq(manager.emailRecoveryModule(), recoveryModuleAddress);
    }
}
