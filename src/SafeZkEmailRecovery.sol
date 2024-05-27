// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ZkEmailRecovery} from "./ZkEmailRecovery.sol";
import {ISafe} from "./interfaces/ISafe.sol";

contract SafeZkEmailRecovery is ZkEmailRecovery {
    error InvalidOldOwner();

    constructor(
        address _verifier,
        address _dkimRegistry,
        address _emailAuthImpl
    ) ZkEmailRecovery(_verifier, _dkimRegistry, _emailAuthImpl) {}

    function recoverySubjectTemplates()
        public
        pure
        override
        returns (string[][] memory)
    {
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

    function validateRecoverySubjectTemplates(
        bytes[] memory subjectParams
    ) internal override returns (address, address) {
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
    }
}
