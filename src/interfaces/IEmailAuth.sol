// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface IEmailAuth {
    function updateDKIMRegistry(address dkimRegistryAddr) external;
    function updateVerifier(address verifierAddr) external;
    function updateSubjectTemplate(uint256 templateId, string[] memory subjectTemplate) external;
    function deleteSubjectTemplate(uint256 templateId) external;
    function setTimestampCheckEnabled(bool enabled) external;
}
