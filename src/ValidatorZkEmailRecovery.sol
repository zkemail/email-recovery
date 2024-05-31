// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ZkEmailRecovery } from "./ZkEmailRecovery.sol";
import { IERC7579Account } from "erc7579/interfaces/IERC7579Account.sol";

contract ValidatorZkEmailRecovery is ZkEmailRecovery {
    error InvalidOldOwner();

    constructor(
        address _verifier,
        address _dkimRegistry,
        address _emailAuthImpl
    )
        ZkEmailRecovery(_verifier, _dkimRegistry, _emailAuthImpl)
    { }

    /**
     * @notice Returns a two-dimensional array of strings representing the subject templates for
     * email recovery.
     * @dev This function is overridden from ZkEmailRecovery. It is
     * re-implemented by this contract to support a different subject template for recovering Safe
     * accounts.
     * in the subject or if the email should be in a language that is not English.
     * @return string[][] A two-dimensional array of strings, where each inner array represents a
     * set of fixed strings and matchers for a subject template.
     */
    function recoverySubjectTemplates() public pure override returns (string[][] memory) {
        string[][] memory templates = new string[][](1);
        templates[0] = new string[](9);
        templates[0][0] = "Recover";
        templates[0][1] = "account";
        templates[0][2] = "{ethAddr}";
        templates[0][3] = "with";
        templates[0][4] = "validator";
        templates[0][5] = "{ethAddr}";
        templates[0][6] = "using";
        templates[0][7] = "calldata";
        templates[0][8] = "{string}";
        return templates;
    }

    /**
     * @notice Validates the recovery subject templates and extracts the account address
     * @dev This function is overridden from ZkEmailRecovery. It is re-implemented by
     * this contract to support a different subject template for recovering Safe accounts.
     * This function reverts if the subject parameters are invalid. The function
     * should extract and return the account address as that is required by
     * the core recovery logic.
     * @param templateIdx The index of the template used for the recovery request
     * @param subjectParams An array of bytes containing the subject parameters
     * @return accountInEmail The extracted account address from the subject parameters
     */
    function validateRecoverySubjectTemplates(
        uint256 templateIdx,
        bytes[] memory subjectParams
    )
        internal
        view
        override
        returns (address)
    {
        if (templateIdx != 0) {
            revert InvalidTemplateIndex();
        }

        if (subjectParams.length != 3) {
            revert InvalidSubjectParams();
        }

        address accountInEmail = abi.decode(subjectParams[0], (address));
        address validatorInEmail = abi.decode(subjectParams[1], (address));
        bytes memory callData = bytes(abi.decode(subjectParams[2], (string)));

        // TODO: validate

        return accountInEmail;
    }
}
