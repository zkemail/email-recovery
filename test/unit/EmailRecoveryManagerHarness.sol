// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { EmailRecoveryManager } from "src/EmailRecoveryManager.sol";
import { EnumerableGuardianMap, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";
import { GuardianUtils } from "src/libraries/GuardianUtils.sol";

contract EmailRecoveryManagerHarness is EmailRecoveryManager {
    using GuardianUtils for mapping(address => EnumerableGuardianMap.AddressToGuardianMap);

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
        guardiansStorage.updateGuardianStatus(account, guardian, newStatus);
    }

    function exposed_removeAllGuardians(address account) external {
        guardiansStorage.removeAllGuardians(account);
    }
}
