// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ERC7579ExecutorBase } from "@rhinestone/modulekit/src/Modules.sol";
import { IERC7579Account } from "erc7579/interfaces/IERC7579Account.sol";
import { IModule } from "erc7579/interfaces/IERC7579Module.sol";
import { ExecutionLib } from "erc7579/lib/ExecutionLib.sol";
import { ModeLib } from "erc7579/lib/ModeLib.sol";

import { IRecoveryModule } from "../interfaces/IRecoveryModule.sol";
import { IEmailRecoveryManager } from "../interfaces/IEmailRecoveryManager.sol";
import { ISafe } from "../interfaces/ISafe.sol";
import { BytesLib } from "../libraries/BytesLib.sol";

contract EmailRecoveryModule is ERC7579ExecutorBase, IRecoveryModule {
    using BytesLib for bytes;
    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    address public immutable emailRecoveryManager;

    event NewValidatorRecovery(address indexed validatorModule, bytes4 recoverySelector);

    error NotTrustedRecoveryManager();
    error InvalidSubjectParams();
    error InvalidValidator(address validator);
    error InvalidSelector(bytes4 selector);

    mapping(address validatorModule => mapping(address account => bytes4 allowedSelector)) internal
        allowedSelectors;
    mapping(address account => address validator) internal validators;

    constructor(address _zkEmailRecovery) {
        emailRecoveryManager = _zkEmailRecovery;
    }

    modifier withoutUnsafeSelector(bytes4 recoverySelector) {
        if (
            recoverySelector == IModule.onUninstall.selector
                || recoverySelector == IModule.onInstall.selector
        ) {
            revert InvalidSelector(recoverySelector);
        }

        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * Initialize the module with the given data
     * @param data The data to initialize the module with
     */
    function onInstall(bytes calldata data) external {
        (
            address validator,
            bytes4 selector,
            address[] memory guardians,
            uint256[] memory weights,
            uint256 threshold,
            uint256 delay,
            uint256 expiry
        ) = abi.decode(data, (address, bytes4, address[], uint256[], uint256, uint256, uint256));

        allowValidatorRecovery(validator, bytes("0"), selector);
        validators[msg.sender] = validator;

        _execute({
            to: emailRecoveryManager,
            value: 0,
            data: abi.encodeCall(
                IEmailRecoveryManager.configureRecovery,
                (address(this), guardians, weights, threshold, delay, expiry)
            )
        });
    }

    function allowValidatorRecovery(
        address validator,
        bytes memory isInstalledContext,
        bytes4 recoverySelector
    )
        internal
        withoutUnsafeSelector(recoverySelector)
    {
        if (
            !IERC7579Account(msg.sender).isModuleInstalled(
                TYPE_VALIDATOR, validator, isInstalledContext
            )
        ) {
            revert InvalidValidator(validator);
        }

        allowedSelectors[validator][msg.sender] = recoverySelector;

        emit NewValidatorRecovery({ validatorModule: validator, recoverySelector: recoverySelector });
    }

    /**
     * De-initialize the module with the given data
     * @custom:unusedparam data - the data to de-initialize the module with
     */
    function onUninstall(bytes calldata /* data */ ) external {
        address validator = validators[msg.sender];
        delete allowedSelectors[validator][msg.sender];
        delete validators[msg.sender];
        IEmailRecoveryManager(emailRecoveryManager).deInitRecoveryFromModule(msg.sender);
    }

    /**
     * Check if the module is initialized
     * @param smartAccount The smart account to check
     * @return true if the module is initialized, false otherwise
     */
    function isInitialized(address smartAccount) external view returns (bool) {
        return IEmailRecoveryManager(emailRecoveryManager).getGuardianConfig(smartAccount).threshold
            != 0;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     MODULE LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    function recover(address account, bytes memory recoveryCalldata) external {
        if (msg.sender != emailRecoveryManager) {
            revert NotTrustedRecoveryManager();
        }

        bytes4 selector = bytes4(recoveryCalldata.slice({ _start: 0, _length: 4 }));

        address validator = validators[account];
        bytes4 allowedSelector = allowedSelectors[validator][account];
        if (allowedSelector != selector) {
            revert InvalidSelector(selector);
        }

        _execute({ account: account, to: validators[account], value: 0, data: recoveryCalldata });
    }

    function getTrustedRecoveryManager() external view returns (address) {
        return emailRecoveryManager;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     METADATA
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * The name of the module
     * @return name The name of the module
     */
    function name() external pure returns (string memory) {
        return "EmailRecoveryModule";
    }

    /**
     * The version of the module
     * @return version The version of the module
     */
    function version() external pure returns (string memory) {
        return "0.0.1";
    }

    /**
     * Check if the module is of a certain type
     * @param typeID The type ID to check
     * @return true if the module is of the given type, false otherwise
     */
    function isModuleType(uint256 typeID) external pure returns (bool) {
        return typeID == TYPE_EXECUTOR;
    }
}
