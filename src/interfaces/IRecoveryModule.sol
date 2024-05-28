// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface IRecoveryModule {
    function recover(address account, bytes[] memory subjectParams) external;
}
