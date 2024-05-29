// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import {EmailAuth} from "ether-email-auth/packages/contracts/src/EmailAuth.sol";
import {ECDSAOwnedDKIMRegistry} from "ether-email-auth/packages/contracts/src/utils/ECDSAOwnedDKIMRegistry.sol";

import {UnitBase} from "../UnitBase.t.sol";
import {IZkEmailRecovery} from "src/interfaces/IZkEmailRecovery.sol";
import {OwnableValidatorRecoveryModule} from "src/modules/OwnableValidatorRecoveryModule.sol";

contract ZkEmailRecovery_updateGuardianDKIMRegistry_Test is UnitBase {
    OwnableValidatorRecoveryModule recoveryModule;
    address recoveryModuleAddress;

    function setUp() public override {
        super.setUp();

        recoveryModule = new OwnableValidatorRecoveryModule{salt: "test salt"}(
            address(zkEmailRecovery)
        );
        recoveryModuleAddress = address(recoveryModule);
    }

    function test_UpdateGuardianDKIMRegistry_RevertWhen_UnauthorizedAccountForGuardian()
        public
    {
        address guardian = guardian1;

        ECDSAOwnedDKIMRegistry newDkim = new ECDSAOwnedDKIMRegistry(
            accountAddress
        );
        address newDkimAddr = address(newDkim);

        vm.expectRevert(
            IZkEmailRecovery.UnauthorizedAccountForGuardian.selector
        );
        zkEmailRecovery.updateGuardianDKIMRegistry(guardian, newDkimAddr);
    }

    function test_UpdateGuardianDKIMRegistry_RevertWhen_RecoveryInProcess()
        public
    {
        address guardian = guardian1;

        ECDSAOwnedDKIMRegistry newDkim = new ECDSAOwnedDKIMRegistry(
            accountAddress
        );
        address newDkimAddr = address(newDkim);

        vm.startPrank(accountAddress);
        zkEmailRecovery.configureRecovery(
            recoveryModuleAddress,
            guardians,
            guardianWeights,
            threshold,
            delay,
            expiry
        );
        vm.stopPrank();

        acceptGuardian(accountSalt1);
        vm.warp(12 seconds);
        handleRecovery(recoveryModuleAddress, accountSalt1);

        vm.startPrank(accountAddress);
        vm.expectRevert(IZkEmailRecovery.RecoveryInProcess.selector);
        zkEmailRecovery.updateGuardianDKIMRegistry(guardian, newDkimAddr);
    }

    function test_UpdateGuardianDKIMRegistry_Succeeds() public {
        address guardian = guardian1;
        EmailAuth guardianEmailAuth = EmailAuth(guardian);

        ECDSAOwnedDKIMRegistry newDkim = new ECDSAOwnedDKIMRegistry(
            accountAddress
        );
        address newDkimAddr = address(newDkim);

        vm.startPrank(accountAddress);
        zkEmailRecovery.configureRecovery(
            recoveryModuleAddress,
            guardians,
            guardianWeights,
            threshold,
            delay,
            expiry
        );
        vm.stopPrank();

        acceptGuardian(accountSalt1);

        address dkim = guardianEmailAuth.dkimRegistryAddr();
        assertEq(dkim, address(ecdsaOwnedDkimRegistry));

        vm.startPrank(accountAddress);
        zkEmailRecovery.updateGuardianDKIMRegistry(guardian, newDkimAddr);

        dkim = guardianEmailAuth.dkimRegistryAddr();
        assertEq(dkim, newDkimAddr);
    }
}
