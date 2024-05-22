// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/console2.sol";
import {ModuleKitHelpers, ModuleKitUserOp} from "modulekit/ModuleKit.sol";
import {MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR} from "modulekit/external/ERC7579.sol";

import {IEmailAccountRecovery} from "src/interfaces/IEmailAccountRecovery.sol";
import {OwnableValidatorRecoveryModule} from "src/modules/OwnableValidatorRecoveryModule.sol";
import {IZkEmailRecovery} from "src/interfaces/IZkEmailRecovery.sol";
import {OwnableValidator} from "src/test/OwnableValidator.sol";

import {Integration_Test} from "../Integration.t.sol";

contract OwnableValidatorRecovery_Integration_Test is Integration_Test {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    OwnableValidator validator;
    OwnableValidatorRecoveryModule recoveryModule;

    function setUp() public override {
        super.setUp();

        validator = new OwnableValidator();
        recoveryModule = new OwnableValidatorRecoveryModule(
            address(zkEmailRecovery)
        );

        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: abi.encode(owner, address(recoveryModule))
        });
        instance.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: address(recoveryModule),
            data: abi.encode(newOwner, validator)
        });
    }

    function testRecover() public {
        uint templateIdx = 0;

        // Setup recovery
        vm.startPrank(accountAddress);
        zkEmailRecovery.configureRecovery(
            guardians,
            guardianWeights,
            threshold,
            recoveryDelay,
            recoveryExpiry
        );
        vm.stopPrank();

        address router = zkEmailRecovery.getRouterForAccount(accountAddress);

        // Accept guardian 1
        acceptGuardian(
            accountAddress,
            router,
            "Accept guardian request for 0xA5555EE8D73dB453Ae85f23Cccd765417E35600A",
            keccak256(abi.encode("nullifier 1")),
            accountSalt1,
            templateIdx
        );
        IZkEmailRecovery.GuardianStorage
            memory guardianStorage1 = zkEmailRecovery.getGuardian(
                accountAddress,
                guardian1
            );
        assertEq(
            uint256(guardianStorage1.status),
            uint256(IZkEmailRecovery.GuardianStatus.ACCEPTED)
        );
        assertEq(guardianStorage1.weight, uint256(1));

        // Accept guardian 2
        acceptGuardian(
            accountAddress,
            router,
            "Accept guardian request for 0xA5555EE8D73dB453Ae85f23Cccd765417E35600A",
            keccak256(abi.encode("nullifier 1")),
            accountSalt2,
            templateIdx
        );
        IZkEmailRecovery.GuardianStorage
            memory guardianStorage2 = zkEmailRecovery.getGuardian(
                accountAddress,
                guardian2
            );
        assertEq(
            uint256(guardianStorage2.status),
            uint256(IZkEmailRecovery.GuardianStatus.ACCEPTED)
        );
        assertEq(guardianStorage2.weight, uint256(1));

        // Time travel so that EmailAuth timestamp is valid
        vm.warp(12 seconds);
        // handle recovery request for guardian 1
        handleRecovery(
            accountAddress,
            newOwner,
            address(recoveryModule),
            router,
            "Recover account 0xA5555EE8D73dB453Ae85f23Cccd765417E35600A to new owner 0x7240b687730BE024bcfD084621f794C2e4F8408f using recovery module 0xCe7eD0a0e29D6d889D5AFEDc877225f7428DDcfe",
            keccak256(abi.encode("nullifier 2")),
            accountSalt1,
            templateIdx
        );
        IZkEmailRecovery.RecoveryRequest
            memory recoveryRequest = zkEmailRecovery.getRecoveryRequest(
                accountAddress
            );
        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.totalWeight, 1);

        // handle recovery request for guardian 2
        uint256 executeAfter = block.timestamp + recoveryDelay;
        handleRecovery(
            accountAddress,
            newOwner,
            address(recoveryModule),
            router,
            "Recover account 0xA5555EE8D73dB453Ae85f23Cccd765417E35600A to new owner 0x7240b687730BE024bcfD084621f794C2e4F8408f using recovery module 0xCe7eD0a0e29D6d889D5AFEDc877225f7428DDcfe",
            keccak256(abi.encode("nullifier 2")),
            accountSalt2,
            templateIdx
        );
        recoveryRequest = zkEmailRecovery.getRecoveryRequest(accountAddress);
        assertEq(recoveryRequest.executeAfter, executeAfter);
        assertEq(recoveryRequest.totalWeight, 2);

        // Time travel so that the recovery delay has passed
        vm.warp(block.timestamp + recoveryDelay);

        // Complete recovery
        IEmailAccountRecovery(router).completeRecovery();

        recoveryRequest = zkEmailRecovery.getRecoveryRequest(accountAddress);
        address updatedOwner = validator.owners(accountAddress);

        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.totalWeight, 0);
        assertEq(updatedOwner, newOwner);
    }
}
