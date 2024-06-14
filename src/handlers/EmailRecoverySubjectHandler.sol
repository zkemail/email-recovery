// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { IEmailRecoverySubjectHandler } from "../interfaces/IEmailRecoverySubjectHandler.sol";
import { IEmailRecoveryManager } from "../interfaces/IEmailRecoveryManager.sol";

/**
 * Handler contract that defines subject templates and how to validate them
 * This is the default subject handler that will work with any validator.
 */
contract EmailRecoverySubjectHandler is IEmailRecoverySubjectHandler {
    error InvalidSubjectParams();
    error InvalidAccount();
    error InvalidRecoveryModule();

    constructor() { }

    function acceptanceSubjectTemplates() public pure returns (string[][] memory) {
        string[][] memory templates = new string[][](1);
        templates[0] = new string[](5);
        templates[0][0] = "Accept";
        templates[0][1] = "guardian";
        templates[0][2] = "request";
        templates[0][3] = "for";
        templates[0][4] = "{ethAddr}";
        return templates;
    }

    function recoverySubjectTemplates() public pure returns (string[][] memory) {
        string[][] memory templates = new string[][](1);
        templates[0] = new string[](11);
        templates[0][0] = "Recover";
        templates[0][1] = "account";
        templates[0][2] = "{ethAddr}";
        templates[0][3] = "via";
        templates[0][4] = "recovery";
        templates[0][5] = "module";
        templates[0][6] = "{ethAddr}";
        templates[0][7] = "using";
        templates[0][8] = "recovery";
        templates[0][9] = "hash";
        templates[0][10] = "{string}";
        return templates;
    }

    function validateAcceptanceSubject(
        uint256 templateIdx,
        bytes[] calldata subjectParams
    )
        external
        pure
        returns (address)
    {
        if (subjectParams.length != 1) revert InvalidSubjectParams();

        // The GuardianStatus check in acceptGuardian implicitly
        // validates the account, so no need to re-validate here
        address accountInEmail = abi.decode(subjectParams[0], (address));

        return accountInEmail;
    }

    function validateRecoverySubject(
        uint256 templateIdx,
        bytes[] calldata subjectParams,
        address recoveryManager
    )
        public
        view
        returns (address, string memory)
    {
        if (subjectParams.length != 3) {
            revert InvalidSubjectParams();
        }

        address accountInEmail = abi.decode(subjectParams[0], (address));
        address recoveryModuleInEmail = abi.decode(subjectParams[1], (address));
        string memory calldataHashInEmail = abi.decode(subjectParams[2], (string));

        if (accountInEmail == address(0)) {
            revert InvalidAccount();
        }

        // Even though someone could use a malicious contract as the recoveryManager argument, it
        // does not matter in this case as this is only used as part of the recovery flow in the
        // recovery manager. Passing the recovery manager in the constructor here would result
        // in a circular dependency
        address expectedRecoveryModule =
            IEmailRecoveryManager(recoveryManager).getRecoveryConfig(accountInEmail).recoveryModule;
        if (recoveryModuleInEmail == address(0) || recoveryModuleInEmail != expectedRecoveryModule)
        {
            revert InvalidRecoveryModule();
        }

        return (accountInEmail, calldataHashInEmail);
    }
}
