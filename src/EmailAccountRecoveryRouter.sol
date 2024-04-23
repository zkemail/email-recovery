// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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

/** Helper contract that routes relayer calls to correct EmailAccountRecovery implementation */
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
        return
            IEmailAccountRecovery(emailAccountRecoveryImpl)
                .emailAuthImplementation();
    }

    function acceptanceSubjectTemplates()
        external
        view
        returns (string[][] memory)
    {
        return
            IEmailAccountRecovery(emailAccountRecoveryImpl)
                .acceptanceSubjectTemplates();
    }

    function recoverySubjectTemplates()
        external
        view
        returns (string[][] memory)
    {
        return
            IEmailAccountRecovery(emailAccountRecoveryImpl)
                .recoverySubjectTemplates();
    }

    function computeEmailAuthAddress(
        bytes32 accountSalt
    ) external view returns (address) {
        return
            IEmailAccountRecovery(emailAccountRecoveryImpl)
                .computeEmailAuthAddress(accountSalt);
    }

    function computeAcceptanceTemplateId(
        uint templateIdx
    ) external view returns (uint) {
        return
            IEmailAccountRecovery(emailAccountRecoveryImpl)
                .computeAcceptanceTemplateId(templateIdx);
    }

    function computeRecoveryTemplateId(
        uint templateIdx
    ) external view returns (uint) {
        return
            IEmailAccountRecovery(emailAccountRecoveryImpl)
                .computeRecoveryTemplateId(templateIdx);
    }

    function handleAcceptance(
        EmailAuthMsg memory emailAuthMsg,
        uint templateIdx
    ) external {
        IEmailAccountRecovery(emailAccountRecoveryImpl).handleAcceptance(
            emailAuthMsg,
            templateIdx
        );
    }

    function handleRecovery(
        EmailAuthMsg memory emailAuthMsg,
        uint templateIdx
    ) external {
        IEmailAccountRecovery(emailAccountRecoveryImpl).handleRecovery(
            emailAuthMsg,
            templateIdx
        );
    }

    function completeRecovery() external {
        IEmailAccountRecovery(emailAccountRecoveryImpl).completeRecovery();
    }
}
