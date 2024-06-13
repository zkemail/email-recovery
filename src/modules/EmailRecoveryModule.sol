// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ERC7579ExecutorBase } from "@rhinestone/modulekit/src/Modules.sol";
import { IERC7579Account } from "erc7579/interfaces/IERC7579Account.sol";
import { IModule } from "erc7579/interfaces/IERC7579Module.sol";
import { SentinelListLib, SENTINEL, ZERO_ADDRESS } from "sentinellist/SentinelList.sol";
import { IRecoveryModule } from "../interfaces/IRecoveryModule.sol";
import { IEmailRecoveryManager } from "../interfaces/IEmailRecoveryManager.sol";

struct ValidatorList {
    SentinelListLib.SentinelList validators;
    uint256 count;
}

contract EmailRecoveryModule is ERC7579ExecutorBase, IRecoveryModule {
    using SentinelListLib for SentinelListLib.SentinelList;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    address public immutable EMAIL_RECOVERY_MANAGER;

    event NewValidatorRecovery(address indexed validatorModule, bytes4 recoverySelector);
    event RemovedValidatorRecovery(address indexed validatorModule, bytes4 recoverySelector);

    error NotTrustedRecoveryManager();
    error InvalidSubjectParams();
    error InvalidValidator(address validator);
    error InvalidSelector(bytes4 selector);
    error InvalidOnInstallData();
    error InvalidValidatorsLength();
    error InvalidNextValidator();

    mapping(address validatorModule => mapping(address account => bytes4 allowedSelector)) internal
        allowedSelectors;

    mapping(address account => mapping(bytes4 selector => address validator)) internal
        selectorToValidator;

    mapping(address account => ValidatorList validatorList) internal validators;

    constructor(address _zkEmailRecovery) {
        EMAIL_RECOVERY_MANAGER = _zkEmailRecovery;
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
        if (data.length == 0) revert InvalidOnInstallData();
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

        _execute({
            to: EMAIL_RECOVERY_MANAGER,
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
        public
        withoutUnsafeSelector(recoverySelector)
    {
        if (
            !IERC7579Account(msg.sender).isModuleInstalled(
                TYPE_VALIDATOR, validator, isInstalledContext
            )
        ) {
            revert InvalidValidator(validator);
        }

        ValidatorList storage validatorList = validators[msg.sender];
        bool alreadyInitialized = validatorList.validators.alreadyInitialized();
        if (!alreadyInitialized) {
            validatorList.validators.init();
        }
        validatorList.validators.push(validator);
        validatorList.count++;

        allowedSelectors[validator][msg.sender] = recoverySelector;
        selectorToValidator[msg.sender][recoverySelector] = validator;

        emit NewValidatorRecovery({ validatorModule: validator, recoverySelector: recoverySelector });
    }

    function disallowValidatorRecovery(
        address validator,
        address prevValidator,
        bytes memory isInstalledContext,
        bytes4 recoverySelector
    )
        public
    {
        if (
            !IERC7579Account(msg.sender).isModuleInstalled(
                TYPE_VALIDATOR, validator, isInstalledContext
            )
        ) {
            revert InvalidValidator(validator);
        }

        ValidatorList storage validatorList = validators[msg.sender];
        validatorList.validators.pop(prevValidator, validator);
        validatorList.count--;

        delete allowedSelectors[validator][msg.sender];
        delete selectorToValidator[msg.sender][recoverySelector];

        emit RemovedValidatorRecovery({
            validatorModule: validator,
            recoverySelector: recoverySelector
        });
    }

    /**
     * De-initialize the module with the given data
     * @custom:unusedparam data - the data to de-initialize the module with
     */
    function onUninstall(bytes calldata /* data */ ) external {
        ValidatorList storage validatorList = validators[msg.sender];

        (address[] memory allowedValidators, address next) =
            validatorList.validators.getEntriesPaginated(SENTINEL, validatorList.count);

        uint256 allowedValidatorsLength = allowedValidators.length;
        if (validatorList.count != allowedValidatorsLength) {
            revert InvalidValidatorsLength();
        }

        if (next != ZERO_ADDRESS) {
            revert InvalidNextValidator();
        }

        for (uint256 i; i < allowedValidatorsLength; i++) {
            bytes4 allowedSelector = allowedSelectors[allowedValidators[i]][msg.sender];
            delete selectorToValidator[msg.sender][allowedSelector];
            delete allowedSelectors[allowedValidators[i]][msg.sender];
        }

        validatorList.validators.popAll();
        validatorList.count = 0;

        IEmailRecoveryManager(EMAIL_RECOVERY_MANAGER).deInitRecoveryFromModule(msg.sender);
    }

    /**
     * Check if the module is initialized
     * @param smartAccount The smart account to check
     * @return true if the module is initialized, false otherwise
     */
    function isInitialized(address smartAccount) external view returns (bool) {
        return IEmailRecoveryManager(EMAIL_RECOVERY_MANAGER).getGuardianConfig(smartAccount)
            .threshold != 0;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     MODULE LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    function recover(address account, bytes calldata recoveryCalldata) external {
        if (msg.sender != EMAIL_RECOVERY_MANAGER) {
            revert NotTrustedRecoveryManager();
        }

        bytes4 selector = bytes4(recoveryCalldata[:4]);

        address validator = selectorToValidator[account][selector];
        bytes4 allowedSelector = allowedSelectors[validator][account];
        if (allowedSelector != selector) {
            revert InvalidSelector(selector);
        }

        _execute({ account: account, to: validator, value: 0, data: recoveryCalldata });
    }

    function getTrustedRecoveryManager() external view returns (address) {
        return EMAIL_RECOVERY_MANAGER;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     METADATA
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * The name of the module
     * @return name The name of the module
     */
    function name() external pure returns (string memory) {
        return "ZKEmail.EmailRecoveryModule";
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
