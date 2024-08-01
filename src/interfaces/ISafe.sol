// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface ISafe {
    function swapOwner(address prevOwner, address oldOwner, address newOwner) external;
    function isOwner(address owner) external view returns (bool);
    function getOwners() external view returns (address[] memory);
    function setFallbackHandler(address handler) external;
    function setGuard(address guard) external;
}
