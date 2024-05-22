// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRecoveryModule {
    function recover(address account, address newOwner) external;
}
