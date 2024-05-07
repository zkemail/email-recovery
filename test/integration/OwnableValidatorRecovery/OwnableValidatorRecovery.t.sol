// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/console2.sol";
import {ModuleKitHelpers, ModuleKitUserOp} from "modulekit/ModuleKit.sol";
import {MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR} from "modulekit/external/ERC7579.sol";

import {IEmailAccountRecovery} from "src/zkEmailRecovery/EmailAccountRecoveryRouter.sol";
import {OwnableValidatorRecoveryModule} from "src/modules/OwnableValidatorRecoveryModule.sol";
import {IZkEmailRecovery} from "src/interfaces/IZkEmailRecovery.sol";
import {IGuardianManager} from "src/interfaces/IGuardianManager.sol";
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
        address expectedRecoveryId = recoveryModule.computeRecoveryId(
            keccak256(abi.encodePacked(accountAddress)),
            keccak256(abi.encodePacked(newOwner))
        );

        // Setup recovery
        vm.startPrank(accountAddress);
        bytes memory guardianData = abi.encode(guardians, threshold);
        zkEmailRecovery.configureRecovery(guardianData, recoveryDelay);
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
        IGuardianManager.GuardianStatus guardianStatus1 = zkEmailRecovery
            .getGuardianStatus(accountAddress, guardian1);
        assertEq(
            uint256(guardianStatus1),
            uint256(IGuardianManager.GuardianStatus.ACCEPTED)
        );

        // Accept guardian 2
        acceptGuardian(
            accountAddress,
            router,
            "Accept guardian request for 0xA5555EE8D73dB453Ae85f23Cccd765417E35600A",
            keccak256(abi.encode("nullifier 1")),
            accountSalt2,
            templateIdx
        );
        IGuardianManager.GuardianStatus guardianStatus2 = zkEmailRecovery
            .getGuardianStatus(accountAddress, guardian2);
        assertEq(
            uint256(guardianStatus2),
            uint256(IGuardianManager.GuardianStatus.ACCEPTED)
        );

        // Time travel so that EmailAuth timestamp is valid
        vm.warp(12 seconds);

        // handle recovery request for guardian 1
        handleRecovery(
            accountAddress,
            address(recoveryModule),
            expectedRecoveryId,
            router,
            "Recover account 0xA5555EE8D73dB453Ae85f23Cccd765417E35600A using recovery module 0xCe7eD0a0e29D6d889D5AFEDc877225f7428DDcfe with request ID 0x78545Bf63Fa4AE73eDfDDe7F12C8b22966D81A22",
            keccak256(abi.encode("nullifier 2")),
            accountSalt1,
            templateIdx
        );
        IZkEmailRecovery.RecoveryRequest
            memory recoveryRequest = zkEmailRecovery.getRecoveryRequest(
                accountAddress
            );
        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.approvalCount, 1);

        // handle recovery request for guardian 2
        uint256 executeAfter = block.timestamp + recoveryDelay;
        handleRecovery(
            accountAddress,
            address(recoveryModule),
            expectedRecoveryId,
            router,
            "Recover account 0xA5555EE8D73dB453Ae85f23Cccd765417E35600A using recovery module 0xCe7eD0a0e29D6d889D5AFEDc877225f7428DDcfe with request ID 0x78545Bf63Fa4AE73eDfDDe7F12C8b22966D81A22",
            keccak256(abi.encode("nullifier 2")),
            accountSalt2,
            templateIdx
        );
        recoveryRequest = zkEmailRecovery.getRecoveryRequest(accountAddress);
        assertEq(recoveryRequest.executeAfter, executeAfter);
        assertEq(recoveryRequest.approvalCount, 2);

        // Time travel so that the recovery delay has passed
        vm.warp(block.timestamp + recoveryDelay);

        // Complete recovery
        IEmailAccountRecovery(router).completeRecovery();

        recoveryRequest = zkEmailRecovery.getRecoveryRequest(accountAddress);
        address updatedOwner = validator.owners(accountAddress);

        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.approvalCount, 0);
        assertEq(updatedOwner, newOwner);
    }
}
