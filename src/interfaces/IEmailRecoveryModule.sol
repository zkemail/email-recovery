// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface IEmailRecoveryModule {
    function isAuthorizedToRecover(address account) external returns (bool);
    function recover(address account, bytes memory recoveryCalldata) external;
    function getTrustedRecoveryManager() external returns (address);
}
