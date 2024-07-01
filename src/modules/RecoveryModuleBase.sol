import { IEmailRecoveryManager } from "../interfaces/IEmailRecoveryManager.sol";
import { ERC7579ExecutorBase } from "@rhinestone/modulekit/src/Modules.sol";
import { IEmailRecoveryModule } from "../interfaces/IEmailRecoveryModule.sol";
import { IModule } from "erc7579/interfaces/IERC7579Module.sol";
import { IERC7579Account } from "erc7579/interfaces/IERC7579Account.sol";

abstract contract RecoveryModuleBase is IEmailRecoveryModule, ERC7579ExecutorBase {
    IEmailRecoveryManager internal immutable EMAIL_RECOVERY_MANAGER;

    error UnauthorizedOnlyEmailRecoveryManager();

    error InvalidSelector(bytes4 selector);
    error InvalidValidator(address validator);

    constructor(address _emailRecoveryManager) {
        EMAIL_RECOVERY_MANAGER = IEmailRecoveryManager(_emailRecoveryManager);
    }

    /**
     * Check if the module is initialized
     * @param smartAccount The smart account to check
     * @return true if the module is initialized, false otherwise
     */
    function isInitialized(address smartAccount) external view returns (bool) {
        return EMAIL_RECOVERY_MANAGER.getGuardianConfig(smartAccount).threshold != 0;
    }

    /**
     * @notice Returns the address of the trusted recovery manager.
     * @return address The address of the email recovery manager.
     */
    function getTrustedRecoveryManager() external view returns (address) {
        return address(EMAIL_RECOVERY_MANAGER);
    }

    /**
     * Returns the type of the module
     * @param typeID type of the module
     * @return true if the type is a module type, false otherwise
     */
    function isModuleType(uint256 typeID) external pure returns (bool) {
        return typeID == TYPE_EXECUTOR;
    }

    function _requireSafeSelectors(bytes4 selector) internal pure {
        if (selector == IModule.onUninstall.selector || selector == IModule.onInstall.selector) {
            revert InvalidSelector(selector);
        }
    }

    /**
     * @notice Modifier to check whether the selector is safe. Reverts if the selector is for
     * "onInstall" or "onUninstall"
     */
    modifier withoutUnsafeSelector(bytes4 recoverySelector) {
        _requireSafeSelectors(recoverySelector);
        _;
    }

    modifier onlyRecoveryManager() {
        if (msg.sender != address(EMAIL_RECOVERY_MANAGER)) {
            revert UnauthorizedOnlyEmailRecoveryManager();
        }
        _;
    }

    function _requireModuleInstalled(
        address account,
        address module,
        bytes memory context
    )
        internal
        view
    {
        if (!IERC7579Account(account).isModuleInstalled(TYPE_VALIDATOR, module, context)) {
            revert InvalidValidator(module);
        }
    }

    function _configureRecoveryManager(
        address[] memory guardians,
        uint256[] memory weights,
        uint256 threshold,
        uint256 delay,
        uint256 expiry
    )
        internal
    {
        _execute({
            to: address(EMAIL_RECOVERY_MANAGER),
            value: 0,
            data: abi.encodeCall(
                IEmailRecoveryManager.configureRecovery, (guardians, weights, threshold, delay, expiry)
            )
        });
    }
}
