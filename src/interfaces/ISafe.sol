// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISafe {
    function getOwners() external view returns (address[] memory);
    function isOwner(address owner) external view returns (bool);
}
