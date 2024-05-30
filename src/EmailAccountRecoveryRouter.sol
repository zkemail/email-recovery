// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { EmailAuthMsg } from "ether-email-auth/packages/contracts/src/EmailAuth.sol";
import { IEmailAccountRecovery } from "./interfaces/IEmailAccountRecovery.sol";

/**
 * Helper contract that routes relayer calls to correct EmailAccountRecovery implementation
 */
contract EmailAccountRecoveryRouter {
    address public immutable emailAccountRecoveryImpl;

    constructor(address _emailAccountRecoveryImpl) {
        emailAccountRecoveryImpl = _emailAccountRecoveryImpl;
    }

    function verifier() external view returns (address) {
        return IEmailAccountRecovery(emailAccountRecoveryImpl).verifier();
    }

    function dkim() external view returns (address) {
        return IEmailAccountRecovery(emailAccountRecoveryImpl).dkim();
    }

    function emailAuthImplementation() external view returns (address) {
        return IEmailAccountRecovery(emailAccountRecoveryImpl).emailAuthImplementation();
    }

    function acceptanceSubjectTemplates() external view returns (string[][] memory) {
        return IEmailAccountRecovery(emailAccountRecoveryImpl).acceptanceSubjectTemplates();
    }

    function recoverySubjectTemplates() external view returns (string[][] memory) {
        return IEmailAccountRecovery(emailAccountRecoveryImpl).recoverySubjectTemplates();
    }

    function computeEmailAuthAddress(bytes32 accountSalt) external view returns (address) {
        return IEmailAccountRecovery(emailAccountRecoveryImpl).computeEmailAuthAddress(accountSalt);
    }

    function computeAcceptanceTemplateId(uint256 templateIdx) external view returns (uint256) {
        return
            IEmailAccountRecovery(emailAccountRecoveryImpl).computeAcceptanceTemplateId(templateIdx);
    }

    function computeRecoveryTemplateId(uint256 templateIdx) external view returns (uint256) {
        return
            IEmailAccountRecovery(emailAccountRecoveryImpl).computeRecoveryTemplateId(templateIdx);
    }

    function handleAcceptance(EmailAuthMsg memory emailAuthMsg, uint256 templateIdx) external {
        IEmailAccountRecovery(emailAccountRecoveryImpl).handleAcceptance(emailAuthMsg, templateIdx);
    }

    function handleRecovery(EmailAuthMsg memory emailAuthMsg, uint256 templateIdx) external {
        IEmailAccountRecovery(emailAccountRecoveryImpl).handleRecovery(emailAuthMsg, templateIdx);
    }

    function completeRecovery() external {
        IEmailAccountRecovery(emailAccountRecoveryImpl).completeRecovery();
    }
}
