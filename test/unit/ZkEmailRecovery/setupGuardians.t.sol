// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import {UnitBase} from "../UnitBase.t.sol";
import {IZkEmailRecovery} from "src/interfaces/IZkEmailRecovery.sol";

contract ZkEmailRecovery_setupGuardians_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_SetupGuardians_RevertWhen_SetupAlreadyCalled() public {
        zkEmailRecovery.exposed_setupGuardians(
            accountAddress,
            guardians,
            guardianWeights,
            threshold
        );

        vm.expectRevert(IZkEmailRecovery.SetupAlreadyCalled.selector);
        zkEmailRecovery.exposed_setupGuardians(
            accountAddress,
            guardians,
            guardianWeights,
            threshold
        );
    }

    function test_SetupGuardians_RevertWhen_IncorrectNumberOfWeights() public {
        uint256[] memory invalidGuardianWeights = new uint256[](4);
        invalidGuardianWeights[0] = 1;
        invalidGuardianWeights[1] = 1;
        invalidGuardianWeights[2] = 1;
        invalidGuardianWeights[3] = 1;

        vm.expectRevert(IZkEmailRecovery.IncorrectNumberOfWeights.selector);
        zkEmailRecovery.exposed_setupGuardians(
            accountAddress,
            guardians,
            invalidGuardianWeights,
            threshold
        );
    }

    function test_SetupGuardians_RevertWhen_ThresholdIsZero() public {
        uint256 zeroThreshold = 0;

        vm.expectRevert(IZkEmailRecovery.ThresholdCannotBeZero.selector);
        zkEmailRecovery.exposed_setupGuardians(
            accountAddress,
            guardians,
            guardianWeights,
            zeroThreshold
        );
    }

    function test_SetupGuardians_RevertWhen_InvalidGuardianAddress() public {
        guardians[2] = address(0);

        vm.expectRevert(IZkEmailRecovery.InvalidGuardianAddress.selector);
        zkEmailRecovery.exposed_setupGuardians(
            accountAddress,
            guardians,
            guardianWeights,
            threshold
        );
    }

    function test_SetupGuardians_RevertWhen_InvalidGuardianWeight() public {
        guardianWeights[1] = 0;

        vm.expectRevert(IZkEmailRecovery.InvalidGuardianWeight.selector);
        zkEmailRecovery.exposed_setupGuardians(
            accountAddress,
            guardians,
            guardianWeights,
            threshold
        );
    }

    function test_SetupGuardians_RevertWhen_ThresholdExceedsTotalWeight()
        public
    {
        uint256 invalidThreshold = 4;

        vm.expectRevert(
            IZkEmailRecovery.ThresholdCannotExceedTotalWeight.selector
        );
        zkEmailRecovery.exposed_setupGuardians(
            accountAddress,
            guardians,
            guardianWeights,
            invalidThreshold
        );
    }

    function test_SetupGuardians_SetupGuardians_Succeeds() public {
        zkEmailRecovery.exposed_setupGuardians(
            accountAddress,
            guardians,
            guardianWeights,
            threshold
        );
    }
}
