// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ERC7579ExecutorBase } from "@rhinestone/modulekit/src/Modules.sol";
import { IERC7579Account } from "erc7579/interfaces/IERC7579Account.sol";
import { IModule } from "erc7579/interfaces/IERC7579Module.sol";
import { SentinelListLib, SENTINEL, ZERO_ADDRESS } from "sentinellist/SentinelList.sol";
import { IRecoveryModule } from "../interfaces/IRecoveryModule.sol";
import { IEmailRecoveryManager } from "../interfaces/IEmailRecoveryManager.sol";
import "forge-std/console2.sol";

struct ValidatorList {
    SentinelListLib.SentinelList validators;
    uint256 count;
}

contract EmailRecoveryModule is ERC7579ExecutorBase, IRecoveryModule {
    using SentinelListLib for SentinelListLib.SentinelList;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    address public immutable emailRecoveryManager;

    event NewValidatorRecovery(address indexed validatorModule, bytes4 recoverySelector);
    event RemovedValidatorRecovery(address indexed validatorModule, bytes4 recoverySelector);

    error InvalidSelector(bytes4 selector);
    error InvalidOnInstallData();
    error InvalidValidator(address validator);
    error InvalidNextValidator();
    error InvalidValidatorsLength();
    error NotTrustedRecoveryManager();

    mapping(address account => ValidatorList validatorList) internal validators;
    mapping(address validatorModule => mapping(address account => bytes4 allowedSelector)) internal
        allowedSelectors;
    mapping(bytes4 selector => mapping(address account => address validator)) internal
        selectorToValidator;

    constructor(address _emailRecoveryManager) {
        emailRecoveryManager = _emailRecoveryManager;
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
            bytes4 initialSelector,
            address[] memory guardians,
            uint256[] memory weights,
            uint256 threshold,
            uint256 delay,
            uint256 expiry
        ) = abi.decode(data, (address, bytes4, address[], uint256[], uint256, uint256, uint256));

        // TODO: Should isInstalledContext be passed in?
        allowValidatorRecovery(validator, bytes("0"), initialSelector);

        _execute({
            to: emailRecoveryManager,
            value: 0,
            data: abi.encodeCall(
                IEmailRecoveryManager.configureRecovery, (guardians, weights, threshold, delay, expiry)
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
        selectorToValidator[recoverySelector][msg.sender] = validator;

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

        if (allowedSelectors[validator][msg.sender] != recoverySelector) {
            revert InvalidSelector(recoverySelector);
        }

        delete allowedSelectors[validator][msg.sender];
        delete selectorToValidator[recoverySelector][msg.sender];

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

        address[] memory allowedValidators = getAllowedValidators(account);

        uint256 allowedValidatorsLength = allowedValidators.length;
        if (validatorList.count != allowedValidatorsLength) {
            revert InvalidValidatorsLength();
        }

        for (uint256 i; i < allowedValidatorsLength; i++) {
            bytes4 allowedSelector = allowedSelectors[allowedValidators[i]][msg.sender];
            delete selectorToValidator[allowedSelector][msg.sender];
            delete allowedSelectors[allowedValidators[i]][msg.sender];
        }

        validatorList.validators.popAll();
        validatorList.count = 0;

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

    function recover(address account, bytes calldata recoveryCalldata) external {
        if (msg.sender != emailRecoveryManager) {
            revert NotTrustedRecoveryManager();
        }

        bytes4 selector = bytes4(recoveryCalldata[:4]);

        address validator = selectorToValidator[selector][account];
        bytes4 allowedSelector = allowedSelectors[validator][account];
        if (allowedSelector != selector) {
            revert InvalidSelector(selector);
        }

        _execute({ account: account, to: validator, value: 0, data: recoveryCalldata });
    }

    function getTrustedRecoveryManager() external view returns (address) {
        return emailRecoveryManager;
    }

    function getAllowedValidators(address account) public view returns (address[] memory) {
        ValidatorList storage validatorList = validators[account];

        // getEntriesPaginated pageCount cannot be zero
        uint256 pageCount = validatorList.count == 0 ? 1 : validatorList.count;
        (address[] memory allowedValidators,) =
            validatorList.validators.getEntriesPaginated(SENTINEL, pageCount);

        return allowedValidators;
    }

    function getAllowedSelectors(address account) external view returns (bytes4[] memory) {
        address[] memory allowedValidators = getAllowedValidators(account);
        uint256 allowedValidatorsLength = allowedValidators.length;

        bytes4[] memory selectors = new bytes4[](allowedValidatorsLength);
        for (uint256 i; i < allowedValidatorsLength; i++) {
            selectors[i] = allowedSelectors[allowedValidators[i]][account];
        }

        return selectors;
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
