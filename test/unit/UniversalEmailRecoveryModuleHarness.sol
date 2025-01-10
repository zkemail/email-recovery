// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { SentinelListLib } from "sentinellist/SentinelList.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";
import { UniversalEmailRecoveryModule } from "src/modules/UniversalEmailRecoveryModule.sol";

/// @dev - This file is originally implemented in the EOA-TX-builder module.
//import { IEoaAuth } from "../../../src/interfaces/circuits/IEoaAuth.sol";
import { EoaProof } from "../../../src/interfaces/circuits/IVerifier.sol";


contract UniversalEmailRecoveryModuleHarness is UniversalEmailRecoveryModule {
    using SentinelListLib for SentinelListLib.SentinelList;
    using EnumerableSet for EnumerableSet.AddressSet;

    constructor(
        address verifier,
        address dkimRegistry,
        address emailAuthImpl,
        address commandHandler,
        uint256 minimumDelay,
        address killSwitchAuthorizer
    )
        UniversalEmailRecoveryModule(
            verifier,
            dkimRegistry,
            emailAuthImpl,
            commandHandler,
            minimumDelay,
            killSwitchAuthorizer
        )
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
        bytes32 nullifier,
        EoaProof memory proof,
        uint256[34] calldata pubSignals
    )
        external
    {
        processRecovery(guardian, templateIdx, commandParams, nullifier, proof, pubSignals);
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
        view
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

    function exposed_clearRecoveryRequest(address account) external {
        return clearRecoveryRequest(account);
    }

    function workaround_getVoteCount(address account) external view returns (uint256) {
        return recoveryRequests[account].guardianVoted.values().length;
    }
}
