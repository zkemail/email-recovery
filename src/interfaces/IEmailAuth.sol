// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IEmailAuth {
    function updateDKIMRegistry(address dkimRegistryAddr) external;
    function updateVerifier(address verifierAddr) external;
    function updateSubjectTemplate(
        uint templateId,
        string[] memory subjectTemplate
    ) external;
    function deleteSubjectTemplate(uint templateId) external;
    function setTimestampCheckEnabled(bool enabled) external;
}
