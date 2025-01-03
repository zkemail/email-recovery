// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface IEmailRecoveryCommandHandler {
    function acceptanceCommandTemplates() external pure returns (string[][] memory);
    function recoveryCommandTemplates() external pure returns (string[][] memory);

    function extractRecoveredAccountFromAcceptanceCommand(
        bytes[] memory commandParams,
        uint256 templateIdx
    )
        external
        view
        returns (address);

    function extractRecoveredAccountFromRecoveryCommand(
        bytes[] memory commandParams,
        uint256 templateIdx
    )
        external
        view
        returns (address);

    function validateAcceptanceCommand(
        uint256 templateIdx,
        bytes[] memory commandParams
    )
        external
        view
        returns (address);

    function validateRecoveryCommand(
        uint256 templateIdx,
        bytes[] memory commandParams
    )
        external
        view
        returns (address);

    function parseRecoveryDataHash(
        uint256 templateIdx,
        bytes[] memory commandParams
    )
        external
        view
        returns (bytes32, bytes memory);
}
