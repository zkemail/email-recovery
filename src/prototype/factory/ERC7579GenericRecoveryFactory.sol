// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import { ERC7579GenericRecoveryModule } from "../ERC7579GenericRecoveryModule.sol";

/**
 * @title RecoveryFactory
 * @notice This contract facilitates the deployment of generic recovery modules.
 * Create2 is leveraged to ensure deterministic addresses, which assists with module
 * attestations
 */
contract ERC7579GenericRecoveryFactory {

    event RecoveryModuleDeployed(
        address validator,
        bytes4 functionSelector
    );

    /**
     * @notice Deploys a generic recovery module
     *
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
