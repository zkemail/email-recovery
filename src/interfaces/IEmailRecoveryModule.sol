// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface IEmailRecoveryModule {
    function isAuthorizedToBeRecovered(address account) external returns (bool);
    function canStartRecoveryRequest(address smartAccount) external view returns (bool);
}
