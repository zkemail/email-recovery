// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { EmailAuthMsg } from "ether-email-auth/packages/contracts/src/EmailAuth.sol";

interface IEmailAccountRecovery {
    function verifier() external view returns (address);

    function dkim() external view returns (address);

    function emailAuthImplementation() external view returns (address);

    function acceptanceSubjectTemplates() external view returns (string[][] memory);

    function recoverySubjectTemplates() external view returns (string[][] memory);

    function computeEmailAuthAddress(bytes32 accountSalt) external view returns (address);

    function computeAcceptanceTemplateId(uint256 templateIdx) external view returns (uint256);

    function computeRecoveryTemplateId(uint256 templateIdx) external view returns (uint256);

    function handleAcceptance(EmailAuthMsg memory emailAuthMsg, uint256 templateIdx) external;

    function handleRecovery(EmailAuthMsg memory emailAuthMsg, uint256 templateIdx) external;

    function completeRecovery() external;
}
