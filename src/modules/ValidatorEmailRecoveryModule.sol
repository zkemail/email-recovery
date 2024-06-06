// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ERC7579ExecutorBase } from "@rhinestone/modulekit/src/Modules.sol";
import { IERC7579Account } from "erc7579/interfaces/IERC7579Account.sol";
import { IModule } from "erc7579/interfaces/IERC7579Module.sol";
import { ExecutionLib } from "erc7579/lib/ExecutionLib.sol";
import { ModeLib } from "erc7579/lib/ModeLib.sol";

import { IRecoveryModule } from "../interfaces/IRecoveryModule.sol";
import { IZkEmailRecovery } from "../interfaces/IZkEmailRecovery.sol";
import { ISafe } from "../interfaces/ISafe.sol";

contract ValidatorEmailRecoveryModule is ERC7579ExecutorBase, IRecoveryModule {
    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    address public immutable zkEmailRecovery;

    event NewValidatorRecovery(address indexed validatorModule, bytes4 recoverySelector);

    error NotTrustedRecoveryContract();
    error InvalidSubjectParams();
    error InvalidValidator(address validator);
    error InvalidSelector(bytes4 selector);

    mapping(address account => address validator) public validators;
    mapping(address validatorModule => mapping(address account => bytes4 allowedSelector)) internal
        $allowedSelector;

    // mapping(=>) internal validator;

    constructor(address _zkEmailRecovery) {
        zkEmailRecovery = _zkEmailRecovery;
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
            uint256 expiry,
            string[][] memory acceptanceSubjectTemplate,
            string[][] memory recoverySubjectTemplate
        ) = abi.decode(
            data,
            (
                address,
                bytes4,
                address[],
                uint256[],
                uint256,
                uint256,
                uint256,
                string[][],
                string[][]
            )
        );

        allowValidatorRecovery(validator, bytes("0"), selector);
        validators[msg.sender] = validator;

        _execute({
            to: zkEmailRecovery,
            value: 0,
            data: abi.encodeCall(
                IZkEmailRecovery.configureRecovery,
                (
                    address(this),
                    guardians,
                    weights,
                    threshold,
                    delay,
                    expiry,
                    acceptanceSubjectTemplate,
                    recoverySubjectTemplate
                )
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
        $allowedSelector[validator][msg.sender] = recoverySelector;

        emit NewValidatorRecovery({ validatorModule: validator, recoverySelector: recoverySelector });
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

    function recover(address account, bytes memory recoveryCalldata) external {
        if (msg.sender != zkEmailRecovery) {
            revert NotTrustedRecoveryContract();
        }

        // TODO: check selector
        // bytes4 selector = bytes4(recoveryCalldata.slice({ _start: 0, _length: 4 }));
        // bytes4 selector = bytes4(0);
        // if ($allowedSelector[validator][account] != selector) {
        //     revert InvalidSelector(selector);
        // }

        _execute({ account: account, to: validators[account], value: 0, data: recoveryCalldata });
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
        return "ValidatorEmailRecoveryModule";
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
