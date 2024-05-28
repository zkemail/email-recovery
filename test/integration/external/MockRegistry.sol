// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IERC7484} from "safe7579/interfaces/IERC7484.sol";

/** Used to setup the Safe in SafeIntegrationBase.sol. Taken from safe7579/test/mocks/MockRegistry.sol */
contract MockRegistry is IERC7484 {
    event NewTrustedAttesters();
    event Log(address sender);

    function check(address module) external view override {}

    function checkForAccount(
        address smartAccount,
        address module
    ) external view override {}

    function check(address module, uint256 moduleType) external view override {}

    function checkForAccount(
        address smartAccount,
        address module,
        uint256 moduleType
    ) external view override {}

    function check(address module, address attester) external view override {}

    function check(
        address module,
        uint256 moduleType,
        address attester
    ) external view override {}

    function checkN(
        address module,
        address[] calldata attesters,
        uint256 threshold
    ) external view override {}

    function checkN(
        address module,
        uint256 moduleType,
        address[] calldata attesters,
        uint256 threshold
    ) external view override {}

    function trustAttesters(
        uint8 threshold,
        address[] calldata attesters
    ) external override {
        emit Log(msg.sender);
        emit NewTrustedAttesters();
    }
}
