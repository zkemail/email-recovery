// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import {UnitBase} from "../UnitBase.t.sol";
import {IZkEmailRecovery} from "src/interfaces/IZkEmailRecovery.sol";
import {OwnableValidatorRecoveryModule} from "src/modules/OwnableValidatorRecoveryModule.sol";

contract ZkEmailRecovery_computeRouterAddress_Test is UnitBase {
    OwnableValidatorRecoveryModule recoveryModule;
    address recoveryModuleAddress;

    function setUp() public override {
        super.setUp();

        recoveryModule = new OwnableValidatorRecoveryModule{salt: "test salt"}(
            address(zkEmailRecovery)
        );
        recoveryModuleAddress = address(recoveryModule);
    }

    function test_ComputeRouterAddress_FailsWhen_InvalidSalt() public {
        bytes32 salt = keccak256(abi.encode("I'm not the right salt"));
        address router = zkEmailRecovery.computeRouterAddress(salt);

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

        address expectedRouter = zkEmailRecovery.getRouterForAccount(
            accountAddress
        );

        assertNotEq(router, expectedRouter);
    }

    function test_ComputeRouterAddress_FailsWhen_CorrectSaltValueButWrongEncoding()
        public
    {
        bytes32 salt = keccak256(abi.encodePacked(accountAddress));
        address router = zkEmailRecovery.computeRouterAddress(salt);

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

        address expectedRouter = zkEmailRecovery.getRouterForAccount(
            accountAddress
        );

        assertNotEq(router, expectedRouter);
    }

    function test_ComputeRouterAddress_Succeeds() public {
        bytes32 salt = keccak256(abi.encode(accountAddress));
        address router = zkEmailRecovery.computeRouterAddress(salt);

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

        address expectedRouter = zkEmailRecovery.getRouterForAccount(
            accountAddress
        );

        assertEq(router, expectedRouter);
    }
}
