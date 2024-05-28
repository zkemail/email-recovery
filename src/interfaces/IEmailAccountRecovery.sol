// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {EmailAuthMsg} from "ether-email-auth/packages/contracts/src/EmailAuth.sol";

interface IEmailAccountRecovery {
    function verifier() external view returns (address);

    function dkim() external view returns (address);

    function emailAuthImplementation() external view returns (address);

    function acceptanceSubjectTemplates()
        external
        view
        returns (string[][] memory);

    function recoverySubjectTemplates()
        external
        view
        returns (string[][] memory);

    function computeEmailAuthAddress(
        bytes32 accountSalt
    ) external view returns (address);

    function computeAcceptanceTemplateId(
        uint templateIdx
    ) external view returns (uint);

    function computeRecoveryTemplateId(
        uint templateIdx
    ) external view returns (uint);

    function handleAcceptance(
        EmailAuthMsg memory emailAuthMsg,
        uint templateIdx
    ) external;

    function handleRecovery(
        EmailAuthMsg memory emailAuthMsg,
        uint templateIdx
    ) external;

    function completeRecovery() external;
}
