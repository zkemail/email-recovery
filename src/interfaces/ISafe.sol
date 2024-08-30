// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface ISafe {
    function isOwner(address owner) external view returns (bool);
    function getOwners() external view returns (address[] memory);
    function setFallbackHandler(address handler) external;
    function setGuard(address guard) external;
    function execTransactionFromModule(
        address to,
        uint256 value,
        bytes memory data,
        uint8 operation
    )
        external
        returns (bool success);
    function isModuleEnabled(address module) external view returns (bool);
    function addOwnerWithThreshold(address owner, uint256 _threshold) external;
    function removeOwner(address prevOwner, address owner, uint256 _threshold) external;
    function swapOwner(address prevOwner, address oldOwner, address newOwner) external;
    function changeThreshold(uint256 _threshold) external;
}
