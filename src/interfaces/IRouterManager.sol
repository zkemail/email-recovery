// SPDX-License.Idenitifer: MIT
pragma solidity ^0.8.0;

interface IRouterManager {
    error RouterAlreadyDeployed();

    function getAccountForRouter(
        address recoveryRouter
    ) external view returns (address);

    function getRouterForAccount(
        address account
    ) external view returns (address);
}
