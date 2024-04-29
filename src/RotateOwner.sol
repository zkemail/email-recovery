// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRouterOwner {
    function rotateOwner(bytes calldata data) external;
}

contract RotateOwner is IRouterOwner {
    function rotateOwner(bytes calldata data) external {
        abi.decode(data, ());
    }
}
