// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface IRecoveryModule {
    function recover(address account, bytes memory recoveryCalldata) external;
    function getTrustedRecoveryManager() external returns (address);
    function getAllowedValidators(address account) external view returns (address[] memory);
    function getAllowedSelectors(address account) external view returns (bytes4[] memory);
}
