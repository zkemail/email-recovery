// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import { ERC7579GenericRecoveryModule } from "../ERC7579GenericRecoveryModule.sol";

/**
 * @title EmailRecoveryFactory
 * @notice This contract facilitates the deployment of email recovery modules and their associated
 * command handlers.
 * Create2 is leveraged to ensure deterministic addresses, which assists with module
 * attestations
 */
contract ERC7579GenericRecoveryFactory {

    event RecoveryModuleDeployed(
        address validator,
        bytes4 functionSelector
    );

    /**
     * @notice Deploys an email recovery module along with its command handler
     * @dev The command handler bytecode cannot be determined ahead of time, unlike the recovery
     * module, which is why it is passed in directly. In practice, this means a
     * developer will write their own command handler, and then pass the bytecode into this factory
     * function.
     *
     * This deployment function deploys an `EmailRecoveryModule`, which takes a target validator and
     * target function selector
     * @param recoveryModuleSalt Salt for the recovery module deployment
     * @param minimumDelay Minimum delay for recovery requests
     * @param killSwitchAuthorizer Address of the kill switch authorizer
     * @param validator Address of the validator to be recovered
     * @param functionSelector Function selector for the recovery function to be called on the
     * target validator
     * @return RecoveryModule The deployed recovery module
     */
    function deployRecoveryModule(
        bytes32 recoveryModuleSalt,
        uint256 minimumDelay,
        address killSwitchAuthorizer,
        address validator,
        bytes4 functionSelector
    )
        external
        returns (address)
    {
        // Deploy recovery module
        address recoveryModule = address(
            new ERC7579GenericRecoveryModule{ salt: recoveryModuleSalt }(
                validator,
                functionSelector,
                minimumDelay,
                killSwitchAuthorizer
            )
        );

        emit RecoveryModuleDeployed(
            validator, functionSelector
        );

        return recoveryModule;
    }
}
