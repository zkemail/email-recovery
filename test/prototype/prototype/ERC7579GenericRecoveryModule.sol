// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ERC7579ExecutorBase } from "@rhinestone/modulekit/src/Modules.sol";
import { IERC7579Account } from "erc7579/interfaces/IERC7579Account.sol";
import { IModule } from "erc7579/interfaces/IERC7579Module.sol";
import { IGuardianVerifier, Guardian } from "./interfaces/IGuardianVerifier.sol";
import { RecoveryManager } from "./RecoveryManager.sol";

/**
 * @title GenericRecoveryModule
 * @notice 
 */
contract ERC7579GenericRecoveryModule is RecoveryManager, ERC7579ExecutorBase {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    CONSTANTS & STORAGE                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Validator being recovered
     */
    address public immutable validator;

    /**
     * function selector that is called when recovering validator
     */
    bytes4 public immutable selector;

    // address constant DEFUALT_GUARDIAN_VERIFIER = address(0x0000000000000000000000000000000000000001);

    event RecoveryExecuted(address indexed account, address indexed validator);

    error InvalidSelector(bytes4 selector);
    error InvalidOnInstallData();
    error InvalidValidator(address validator);

    constructor(
        address _validator,
        bytes4 _selector,
        uint256 _minimumDelay,
        address _killSwitchAuthorizer
    )
        RecoveryManager(
            _minimumDelay,
            _killSwitchAuthorizer
        )
    {
        validator = _validator;
        selector = _selector;
    }


    function onInstall(bytes calldata data) external {
        if (data.length == 0) revert InvalidOnInstallData();
        (
            bytes memory isInstalledContext,
            Guardian[] memory guardians,
            uint256[] memory weights,
            uint256 threshold,
            uint256 delay,
            uint256 expiry
        ) = abi.decode(data, (bytes, Guardian[], uint256[], uint256, uint256, uint256));

        if (
            !IERC7579Account(msg.sender).isModuleInstalled(
                TYPE_VALIDATOR, validator, isInstalledContext
            )
        ) {
            revert InvalidValidator(validator);
        }
        configureRecovery(guardians, weights, threshold, delay, expiry);
    }


    function configureRecovery(
        Guardian[] memory guardians,
        uint256[] memory weights,
        uint256 threshold,
        uint256 delay,
        uint256 expiry
    ) internal {
        bytes32[] memory guardianIdentifierHashes = new bytes32[](guardians.length);
        address[] memory guardianVerifiers = new address[](guardians.length);
        for (uint256 i = 0; i < guardians.length; i++) {
            address gVerifier = guardians[i].guardianVerifier;
            guardianVerifiers[i] = gVerifier;
            guardianIdentifierHashes[i] = keccak256(guardians[i].guardian);
        }
        configureRecovery(guardianIdentifierHashes, guardianVerifiers, weights, threshold, delay, expiry);
    }

    /**
     * @notice Handles the uninstallation of the module and clears the recovery configuration
     * @param {data} Unused parameter.
     */
    function onUninstall(bytes calldata /* data */ ) external {
        deInitRecoveryModule();
    }

    /**
     * @notice Check if the module is initialized
     * @param account The smart account to check
     * @return bool True if the module is initialized, false otherwise
     */
    function isInitialized(address account) external view returns (bool) {
        return getGuardianConfig(account).threshold != 0;
    }

    /**
     * @notice Check if a recovery request can be initiated based on guardian acceptance
     * @param account The smart account to check
     * @return bool True if the recovery request can be started, false otherwise
     */
    function canStartRecoveryRequest(address account) external view returns (bool) {
        GuardianConfig memory guardianConfig = getGuardianConfig(account);

        return guardianConfig.threshold > 0
            && guardianConfig.acceptedWeight >= guardianConfig.threshold;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        MODULE LOGIC                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Executes recovery on a validator. Called from the recovery manager once a recovery
     * attempt has been processed
     * @param account The account to execute recovery for
     * @param recoveryData The recovery data that should be executed on the validator
     * being recovered. recoveryData = abi.encode(validator, recoveryFunctionCalldata)
     */
    function recover(address account, bytes calldata recoveryData) internal override {
        (, bytes memory recoveryCalldata) = abi.decode(recoveryData, (address, bytes));

        bytes4 calldataSelector;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            calldataSelector := mload(add(recoveryCalldata, 32))
        }
        if (calldataSelector != selector) {
            revert InvalidSelector(calldataSelector);
        }

        _execute({ account: account, to: validator, value: 0, data: recoveryCalldata });

        emit RecoveryExecuted(account, validator);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         METADATA                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Returns the name of the module
     * @return string name of the module
     */
    function name() external pure returns (string memory) {
        return "ERC7579GenericRecoveryModule";
    }

    /**
     * @notice Returns the version of the module
     * @return string version of the module
     */
    function version() external pure returns (string memory) {
        return "1.0.0";
    }

    /**
     * @notice Returns the type of the module
     * @param typeID type of the module
     * @return bool true if the type is a module type, false otherwise
     */
    function isModuleType(uint256 typeID) external pure returns (bool) {
        return typeID == TYPE_EXECUTOR;
    }
}