// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IUUPSUpgradable {
    function upgradeToAndCall(
        address newImplementation,
        bytes memory data
    ) external payable;
}
