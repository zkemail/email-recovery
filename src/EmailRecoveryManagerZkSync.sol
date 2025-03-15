// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {EmailRecoveryManager} from "./EmailRecoveryManager.sol";
import {EmailAccountRecovery} from "./EmailAccountRecovery.sol";
import {EmailAccountRecoveryZKSync} from "./EmailAccountRecoveryZKSync.sol";

/**
 * @title EmailRecoveryManagerZkSync
 * @notice Provides a mechanism for account recovery using email guardians on ZKSync networks.
 * @dev The underlying EmailAccountRecoveryZkSync contract provides some base logic for deploying
 * guardian contracts and handling email verification.
 */
abstract contract EmailRecoveryManagerZkSync is
    EmailRecoveryManager,
    EmailAccountRecoveryZKSync
{
    constructor(
        uint256 _minimumDelay,
        address _killSwitchAuthorizer,
        address _factoryAddr,
        bytes32 _proxyBytecodeHash
    ) EmailRecoveryManager(_minimumDelay, _killSwitchAuthorizer) {
        if (_factoryAddr == address(0)) {
            revert InvalidFactory();
        }
        if (_proxyBytecodeHash == bytes32(0)) {
            revert InvalidProxyBytecodeHash();
        }
        factoryAddr = _factoryAddr;
        proxyBytecodeHash = _proxyBytecodeHash;
    }

    /// @notice Computes the address for email auth contract using the CREATE2 opcode.
    /// @dev This function utilizes the `ZKSyncCreate2Factory` to compute the address. The computation uses a provided account address to be recovered, account salt,
    /// and the hash of the encoded ERC1967Proxy creation code concatenated with the encoded guardian verifier implementation
    /// address and the initialization call data. This ensures that the computed address is deterministic and unique per account salt.
    /// @param guardianVerifierImplementation The address of the guardian verifier implementation.
    /// @param recoveredAccount The address of the account to be recovered.
    /// @param accountSalt A bytes32 salt value used to ensure the uniqueness of the deployed proxy address.
    /// @param verifierInitData The initialization data for the guardian verifier.
    /// @return address The computed address.
    function computeGuardianVerifierAddress(
        address guardianVerifierImplementation,
        address recoveredAccount,
        bytes32 accountSalt,
        bytes memory verifierInitData
    )
        public
        view
        virtual
        override(EmailAccountRecovery, EmailAccountRecoveryZKSync)
        returns (address)
    {
        return
            EmailAccountRecoveryZKSync.computeGuardianVerifierAddress(
                guardianVerifierImplementation,
                recoveredAccount,
                accountSalt,
                verifierInitData
            );
    }

    /// @notice Deploys a proxy contract for email authentication using the CREATE2 opcode.
    /// @dev This function utilizes the `ZKSyncCreate2Factory` to deploy the proxy contract. The deployment uses a provided account address to be recovered, account salt,
    /// and the hash of the encoded ERC1967Proxy creation code concatenated with the encoded guardian verifier implementation
    /// address and the initialization call data. This ensures that the deployed address is deterministic and unique per account salt.
    /// @param guardianVerifierImplementation The address of the guardian verifier implementation.
    /// @param accountSalt A bytes32 salt value used to ensure the uniqueness of the deployed proxy address.
    /// @param recoveredAccount The address of the account to be recovered.
    /// @param verifierInitData The initialization data for the guardian verifier.
    /// @return address The address of the deployed proxy contract.
    function deployGuardianVerifierProxy(
        address guardianVerifierImplementation,
        address recoveredAccount,
        bytes32 accountSalt,
        bytes memory verifierInitData
    )
        internal
        virtual
        override(EmailAccountRecovery, EmailAccountRecoveryZKSync)
        returns (address)
    {
        return
            EmailAccountRecoveryZKSync.deployGuardianVerifierProxy(
                guardianVerifierImplementation,
                recoveredAccount,
                accountSalt,
                verifierInitData
            );
    }
}
