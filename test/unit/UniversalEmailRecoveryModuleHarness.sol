// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { SentinelListLib } from "sentinellist/SentinelList.sol";
import { EnumerableGuardianMap, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";
import { UniversalEmailRecoveryModule } from "src/modules/UniversalEmailRecoveryModule.sol";

contract UniversalEmailRecoveryModuleHarness is UniversalEmailRecoveryModule {
    using SentinelListLib for SentinelListLib.SentinelList;

    constructor(
        address verifier,
        address dkimRegistry,
        address emailAuthImpl,
        address commandHandler
    )
        UniversalEmailRecoveryModule(verifier, dkimRegistry, emailAuthImpl, commandHandler)
    { }

    function exposed_configureRecovery(
        address[] memory guardians,
        uint256[] memory weights,
        uint256 threshold,
        uint256 delay,
        uint256 expiry
    )
        external
    {
        configureRecovery(guardians, weights, threshold, delay, expiry);
    }

    function exposed_acceptGuardian(
        address guardian,
        uint256 templateIdx,
        bytes[] memory commandParams,
        bytes32 nullifier
    )
        external
    {
        acceptGuardian(guardian, templateIdx, commandParams, nullifier);
    }

    function exposed_processRecovery(
        address guardian,
        uint256 templateIdx,
        bytes[] memory commandParams,
        bytes32 nullifier
    )
        external
    {
        processRecovery(guardian, templateIdx, commandParams, nullifier);
    }

    function exposed_recover(address account, bytes calldata recoveryData) external {
        recover(account, recoveryData);
    }

    function exposed_deInitRecoveryModule() external {
        deInitRecoveryModule();
    }

    function exposed_deInitRecoveryModule(address account) external {
        deInitRecoveryModule(account);
    }

    function exposed_setupGuardians(
        address account,
        address[] calldata guardians,
        uint256[] calldata weights,
        uint256 threshold
    )
        external
        returns (uint256, uint256)
    {
        return setupGuardians(account, guardians, weights, threshold);
    }

    function exposed_updateGuardianStatus(
        address account,
        address guardian,
        GuardianStatus newStatus
    )
        external
    {
        updateGuardianStatus(account, guardian, newStatus);
    }

    function exposed_removeAllGuardians(address account) external {
        removeAllGuardians(account);
    }

    function workaround_validatorsPush(address account, address validator) external {
        validators[account].push(validator);
        validatorCount[account]++;
    }

    function workaround_validatorsContains(
        address account,
        address validator
    )
        external
        returns (bool)
    {
        return validators[account].contains(validator);
    }

    function exposed_allowedSelectors(
        address validator,
        address account
    )
        external
        view
        returns (bytes4)
    {
        return allowedSelectors[validator][account];
    }
}
