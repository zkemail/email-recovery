// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface IEmailRecoverySubjectHandler {
    function acceptanceSubjectTemplates() external pure returns (string[][] memory);
    function recoverySubjectTemplates() external pure returns (string[][] memory);

    function validateAcceptanceSubject(
        uint256 templateIdx,
        bytes[] memory subjectParams
    )
        external
        view
        returns (address);

    function validateRecoverySubject(
        uint256 templateIdx,
        bytes[] memory subjectParams,
        address recoveryManager
    )
        external
        view
        returns (address, string memory);
}
