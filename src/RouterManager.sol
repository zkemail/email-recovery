// SPDX-License.Idenitifer: MIT
pragma solidity ^0.8.0;

import {IRouterManager} from "./interfaces/IRouterManager.sol";
import {EmailAccountRecoveryRouter} from "./EmailAccountRecoveryRouter.sol";

abstract contract RouterManager is IRouterManager {
    /** Mapping of email account recovery router contracts to account */
    mapping(address => address) internal routerToAccount;

    /** Mapping of account account addresses to email account recovery router contracts**/
    /** These are stored for frontends to easily find the router contract address from the given account account address**/
    mapping(address => address) internal accountToRouter;

    /// @inheritdoc IRouterManager
    function getAccountForRouter(
        address recoveryRouter
    ) public view override returns (address) {
        return routerToAccount[recoveryRouter];
    }

    /// @inheritdoc IRouterManager
    function getRouterForAccount(
        address account
    ) public view override returns (address) {
        return accountToRouter[account];
    }

    function deployRouterForAccount(
        address account
    ) internal returns (address) {
        if (accountToRouter[account] != address(0))
            revert RouterAlreadyDeployed();

        EmailAccountRecoveryRouter emailAccountRecoveryRouter = new EmailAccountRecoveryRouter(
                address(this)
            );
        address routerAddress = address(emailAccountRecoveryRouter);

        routerToAccount[routerAddress] = account;
        accountToRouter[account] = routerAddress;

        return routerAddress;
    }
}
