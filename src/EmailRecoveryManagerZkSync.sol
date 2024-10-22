// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { EmailRecoveryManager } from "./EmailRecoveryManager.sol";
import { EmailAccountRecovery } from
    "@zk-email/ether-email-auth-contracts/src/EmailAccountRecovery.sol";
import { EmailAccountRecoveryZKSync } from
    "@zk-email/ether-email-auth-contracts/src/EmailAccountRecoveryZKSync.sol";

/**
 * @title EmailRecoveryManagerZkSync
 * @notice Provides a mechanism for account recovery using email guardians on ZKSync networks.
 * @dev The underlying EmailAccountRecoveryZkSync contract provides some base logic for deploying
 * guardian contracts and handling email verification.
 */
abstract contract EmailRecoveryManagerZkSync is EmailRecoveryManager, EmailAccountRecoveryZKSync {
    constructor(
        address _verifier,
        address _dkimRegistry,
        address _emailAuthImpl,
        address _commandHandler,
        uint256 _minimumDelay,
        address _factoryAddr,
        bytes32 _proxyBytecodeHash
    )
        EmailRecoveryManager(_verifier, _dkimRegistry, _emailAuthImpl, _commandHandler, _minimumDelay)
    {
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
    /// @dev This function utilizes the `ZKSyncCreate2Factory` to compute the address. The
    /// computation uses a provided account address to be recovered, account salt,
    /// and the hash of the encoded ERC1967Proxy creation code concatenated with the encoded email
    /// auth contract implementation
    /// address and the initialization call data. This ensures that the computed address is
    /// deterministic and unique per account salt.
    /// @param recoveredAccount The address of the account to be recovered.
    /// @param accountSalt A bytes32 salt value defined as a hash of the guardian's email address
    /// and an account code. This is assumed to be unique to a pair of the guardian's email address
    /// and the wallet address to be recovered.
    /// @return address The computed address.
    function computeEmailAuthAddress(
        address recoveredAccount,
        bytes32 accountSalt
    )
        public
        view
        virtual
        override(EmailAccountRecovery, EmailAccountRecoveryZKSync)
        returns (address)
    {
        return EmailAccountRecoveryZKSync.computeEmailAuthAddress(recoveredAccount, accountSalt);
    }

    /// @notice Deploys a proxy contract for email authentication using the CREATE2 opcode.
    /// @dev This function utilizes the `ZKSyncCreate2Factory` to deploy the proxy contract. The
    /// deployment uses a provided account address to be recovered, account salt,
    /// and the hash of the encoded ERC1967Proxy creation code concatenated with the encoded email
    /// auth contract implementation
    /// address and the initialization call data. This ensures that the deployed address is
    /// deterministic and unique per account salt.
    /// @param recoveredAccount The address of the account to be recovered.
    /// @param accountSalt A bytes32 salt value defined as a hash of the guardian's email address
    /// and an account code. This is assumed to be unique to a pair of the guardian's email address
    /// and the wallet address to be recovered.
    /// @return address The address of the deployed proxy contract.
    function deployEmailAuthProxy(
        address recoveredAccount,
        bytes32 accountSalt
    )
        internal
        virtual
        override(EmailAccountRecovery, EmailAccountRecoveryZKSync)
        returns (address)
    {
        return EmailAccountRecoveryZKSync.deployEmailAuthProxy(recoveredAccount, accountSalt);
    }
}
