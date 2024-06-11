// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import { EmailRecoveryManager } from "src/EmailRecoveryManager.sol";

contract EmailRecoveryManagerHarness is EmailRecoveryManager {
    constructor(
        address verifier,
        address dkimRegistry,
        address emailAuthImpl,
        address subjectHandler
    )
        EmailRecoveryManager(verifier, dkimRegistry, emailAuthImpl, subjectHandler)
    { }

    function exposed_acceptGuardian(
        address guardian,
        uint256 templateIdx,
        bytes[] memory subjectParams,
        bytes32 nullifier
    )
        external
    {
        acceptGuardian(guardian, templateIdx, subjectParams, nullifier);
    }

    function exposed_processRecovery(
        address guardian,
        uint256 templateIdx,
        bytes[] memory subjectParams,
        bytes32 nullifier
    )
        external
    {
        processRecovery(guardian, templateIdx, subjectParams, nullifier);
    }

    function exposed_setupGuardians(
        address account,
        address[] memory guardians,
        uint256[] memory weights,
        uint256 threshold
    )
        external
    {
        setupGuardians(account, guardians, weights, threshold);
    }
}
