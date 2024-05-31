// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ERC7579ExecutorBase } from "@rhinestone/modulekit/src/Modules.sol";
import { IERC7579Account } from "erc7579/interfaces/IERC7579Account.sol";
import { IERC7579Module } from "erc7579/interfaces/IERC7579Module.sol";
import { ExecutionLib } from "erc7579/lib/ExecutionLib.sol";
import { ModeLib } from "erc7579/lib/ModeLib.sol";

import { IRecoveryModule } from "../interfaces/IRecoveryModule.sol";
import { IZkEmailRecovery } from "../interfaces/IZkEmailRecovery.sol";
import { ISafe } from "../interfaces/ISafe.sol";
import { BytesLib } from "../libraries/BytesLib.sol";

contract ValidatorRecoveryModule is ERC7579ExecutorBase, IRecoveryModule {
    using BytesLib for bytes;
    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    address public immutable zkEmailRecovery;

    event NewValidatorRecovery(address indexed validatorModule, bytes4 recoverySelector);

    error NotTrustedRecoveryContract();
    error InvalidSubjectParams();
    error InvalidValidator(address validator);
    error InvalidSelector(bytes4 selector);

    mapping(address validatorModule => mapping(address account => bytes4 allowedSelector)) internal
        $allowedSelector;

    constructor(address _zkEmailRecovery) {
        zkEmailRecovery = _zkEmailRecovery;
    }

    modifier onlyZkEmailRecovery() {
        if (msg.sender != zkEmailRecovery) revert NotTrustedRecoveryContract();

        _;
    }

    modifier withoutUnsafeSelector(bytes4 recoverySelector) {
        if (
            recoverySelector == IERC7579Module.onUninstall.selector
                || IERC7579Module.onInstall.selector
        ) {
            revert InvalidValidator(recoverySelector);
        }

        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    function allowValidatorRecovery(
        address validator,
        bytes calldata isInstalledContext,
        bytes4 recoverySelector
    )
        public
        withoutUnsafeSelector(recoverySelector)
    {
        if (
            !IERC7579Account(account).isModuleInstalled(
                TYPE_VALIDATOR, validator, isInstalledContext
            )
        ) {
            revert InvalidValidator(validatorModule);
        }
        $allowedSelector[validator][msg.sender] = recoverySelector;

        emit NewValidatorRecovery({ validatorModule: validator, recoverySelector: recoverySelector });
    }

    /**
     * Initialize the module with the given data
     * @param data The data to initialize the module with
     */
    function onInstall(bytes calldata data) external {
        (
            address[] memory guardians,
            uint256[] memory weights,
            uint256 threshold,
            uint256 delay,
            uint256 expiry
        ) = abi.decode(data, (address[], uint256[], uint256, uint256, uint256));

        // TODO: add initialization with allowValidatorRecovery()
        _execute({
            to: zkEmailRecovery,
            value: 0,
            data: abi.encodeCall(
                IZkEmailRecovery.configureRecovery,
                (address(this), guardians, weights, threshold, delay, expiry)
            )
        });
    }

    /**
     * De-initialize the module with the given data
     * @custom:unusedparam data - the data to de-initialize the module with
     */
    function onUninstall(bytes calldata /* data */ ) external {
        IZkEmailRecovery(zkEmailRecovery).deInitRecoveryFromModule(msg.sender);
    }

    /**
     * Check if the module is initialized
     * @param smartAccount The smart account to check
     * @return true if the module is initialized, false otherwise
     */
    function isInitialized(address smartAccount) external view returns (bool) {
        return IZkEmailRecovery(zkEmailRecovery).getGuardianConfig(smartAccount).threshold != 0;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     MODULE LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    function recover(
        address account,
        bytes[] calldata subjectParams
    )
        external
        onlyZkEmailRecovery
    {
        // prevent out of bounds error message, in case subject params are invalid
        if (subjectParams.length < 3) {
            revert InvalidSubjectParams();
        }

        address validatorModule = abi.decode(subjectParams[1], (address));
        bytes memory recoveryCallData = bytes(abi.decode(subjectParams[2], (string)));

        bytes4 selector = bytes4(recoveryCallData.slice({ _start: 0, _length: 4 }));
        if ($allowedSelector[validatorModule][account] != selector) {
            revert InvalidSelector(selector);
        }
        _execute({ account: account, to: validatorModule, value: 0, data: recoveryCallData });
    }

    function getTrustedContract() external view returns (address) {
        return zkEmailRecovery;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     METADATA
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * The name of the module
     * @return name The name of the module
     */
    function name() external pure returns (string memory) {
        return "ValidatorRecoveryModule";
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
