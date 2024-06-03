// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ZkEmailRecovery } from "./ZkEmailRecovery.sol";
import { ISafe } from "./interfaces/ISafe.sol";

/**
 * @title SafeZkEmailRecovery
 * @notice Implements email based recovery for Safe accounts inheriting core logic from ZkEmailRecovery
 * @dev The underlying ZkEmailRecovery contract provides some the core logic for recovering an account
 */
contract SafeZkEmailRecovery is ZkEmailRecovery {
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
     * @dev This function is overridden from ZkEmailRecovery. It overrides the base implementation
     * to provide a template specific to Safe accounts. The template includes placeholders for
     * the account address, old owner, new owner, and recovery module.
     * in the subject or if the email should be in a language that is not English.
     * @return string[][] A two-dimensional array of strings, where each inner array represents a
     * set of fixed strings and matchers for a subject template.
     */
    function recoverySubjectTemplates() public pure override returns (string[][] memory) {
        string[][] memory templates = new string[][](1);
        templates[0] = new string[](15);
        templates[0][0] = "Recover";
        templates[0][1] = "account";
        templates[0][2] = "{ethAddr}";
        templates[0][3] = "from";
        templates[0][4] = "old";
        templates[0][5] = "owner";
        templates[0][6] = "{ethAddr}";
        templates[0][7] = "to";
        templates[0][8] = "new";
        templates[0][9] = "owner";
        templates[0][10] = "{ethAddr}";
        templates[0][11] = "using";
        templates[0][12] = "recovery";
        templates[0][13] = "module";
        templates[0][14] = "{ethAddr}";
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

        if (subjectParams.length != 4) {
            revert InvalidSubjectParams();
        }

        address accountInEmail = abi.decode(subjectParams[0], (address));
        address oldOwnerInEmail = abi.decode(subjectParams[1], (address));
        address newOwnerInEmail = abi.decode(subjectParams[2], (address));
        address recoveryModuleInEmail = abi.decode(subjectParams[3], (address));

        bool isOwner = ISafe(accountInEmail).isOwner(oldOwnerInEmail);
        if (!isOwner) {
            revert InvalidOldOwner();
        }
        if (newOwnerInEmail == address(0)) {
            revert InvalidNewOwner();
        }
        if (recoveryModuleInEmail == address(0)) {
            revert InvalidRecoveryModule();
        }

        return accountInEmail;
    }
}
