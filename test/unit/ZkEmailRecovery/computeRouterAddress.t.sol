// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import { ModuleKitHelpers, ModuleKitUserOp } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/external/ERC7579.sol";
import { UnitBase } from "../UnitBase.t.sol";
import { IZkEmailRecovery } from "src/interfaces/IZkEmailRecovery.sol";
import { OwnableValidatorRecoveryModule } from "src/modules/OwnableValidatorRecoveryModule.sol";
import { OwnableValidator } from "src/test/OwnableValidator.sol";

contract ZkEmailRecovery_computeRouterAddress_Test is UnitBase {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    OwnableValidator validator;
    OwnableValidatorRecoveryModule recoveryModule;
    address recoveryModuleAddress;

    function setUp() public override {
        super.setUp();

        validator = new OwnableValidator();
        recoveryModule =
            new OwnableValidatorRecoveryModule{ salt: "test salt" }(address(zkEmailRecovery));
        recoveryModuleAddress = address(recoveryModule);

        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: abi.encode(owner, recoveryModuleAddress)
        });
        // Install recovery module - configureRecovery is called on `onInstall`
        instance.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: recoveryModuleAddress,
            data: abi.encode(address(validator), guardians, guardianWeights, threshold, delay, expiry)
        });
    }

    function test_ComputeRouterAddress_FailsWhen_InvalidSalt() public {
        bytes32 salt = keccak256(abi.encode("I'm not the right salt"));
        address router = zkEmailRecovery.computeRouterAddress(salt);

        address expectedRouter = zkEmailRecovery.getRouterForAccount(accountAddress);

        assertNotEq(router, expectedRouter);
    }

    function test_ComputeRouterAddress_FailsWhen_CorrectSaltValueButWrongEncoding() public {
        bytes32 salt = keccak256(abi.encodePacked(accountAddress));
        address router = zkEmailRecovery.computeRouterAddress(salt);

        address expectedRouter = zkEmailRecovery.getRouterForAccount(accountAddress);

        assertNotEq(router, expectedRouter);
    }

    function test_ComputeRouterAddress_Succeeds() public {
        bytes32 salt = keccak256(abi.encode(accountAddress));
        address router = zkEmailRecovery.computeRouterAddress(salt);

        address expectedRouter = zkEmailRecovery.getRouterForAccount(accountAddress);

        assertEq(router, expectedRouter);
    }
}
