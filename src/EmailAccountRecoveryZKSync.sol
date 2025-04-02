// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {IGuardianVerifier} from "./interfaces/IGuardianVerifier.sol";
import {EmailAccountRecovery} from "./EmailAccountRecovery.sol";
import {ZKSyncCreate2Factory} from "@zk-email/ether-email-auth-contracts/src/utils/ZKSyncCreate2Factory.sol";

/// @title Email Account Recovery Contract
/// @notice Provides mechanisms for email-based account recovery, leveraging guardians and template-based email verification.
/// @dev This contract is abstract and requires implementation of several methods for configuring a new guardian and recovering an account contract.
abstract contract EmailAccountRecoveryZKSync is EmailAccountRecovery {
    // This is the address of the zkSync factory contract
    address public factoryAddr;
    // The bytecodeHash is assumed to be provided as an initialization parameter because type(ERC1967Proxy).creationCode doesn't work on eraVM currently
    // If you failed some test cases, check the bytecodeHash by yourself
    // see, test/ComputeCreate2Address.t.sol
    bytes32 public proxyBytecodeHash;

    /// @notice Returns the address of the zkSyncfactory contract.
    /// @dev This function is virtual and can be overridden by inheriting contracts.
    /// @return address The address of the zkSync factory contract.
    function factory() public view virtual returns (address) {
        return factoryAddr;
    }

    /// @notice Computes the address for email auth contract using the CREATE2 opcode.
    /// @dev This function utilizes the `ZKSyncCreate2Factory` to compute the address. The computation uses a provided account address to be recovered, account salt,
    /// and the hash of the encoded ERC1967Proxy creation code concatenated with the encoded guardian verifier implementation
    /// address and the initialization call data. This ensures that the computed address is deterministic and unique per account salt.
    /// @param guardianVerifierImplementation The address of the guardian verifier implementation.
    /// @param account The address of the account to be recovered.
    /// @param accountSalt A bytes32 salt value used to ensure the uniqueness of the deployed proxy address.
    /// @param verifierInitData The initialization data for the guardian verifier.
    /// @return address The computed address.
    function computeGuardianVerifierAddress(
        address guardianVerifierImplementation,
        address account,
        bytes32 accountSalt,
        bytes memory verifierInitData
    ) public view virtual override returns (address) {
        // If on zksync, we use another logic to calculate create2 address.
        return
            ZKSyncCreate2Factory(factory()).computeAddress(
                accountSalt,
                proxyBytecodeHash,
                abi.encode(
                    guardianVerifierImplementation,
                    abi.encodeCall(
                        IGuardianVerifier.initialize,
                        (account, accountSalt, verifierInitData)
                    )
                )
            );
    }

    /// @notice Deploys a proxy contract for email authentication using the CREATE2 opcode.
    /// @dev This function utilizes the `ZKSyncCreate2Factory` to deploy the proxy contract. The deployment uses a provided account address to be recovered, account salt,
    /// and the hash of the encoded ERC1967Proxy creation code concatenated with the encoded guardian verifier implementation
    /// address and the initialization call data. This ensures that the deployed address is deterministic and unique per account salt.
    /// @param guardianVerifierImplementation The address of the guardian verifier implementation.
    /// @param accountSalt A bytes32 salt value used to ensure the uniqueness of the deployed proxy address.
    /// @param account The address of the account to be recovered.
    /// @param verifierInitData The initialization data for the guardian verifier.
    /// @return address The address of the deployed proxy contract.
    function deployGuardianVerifierProxy(
        address guardianVerifierImplementation,
        address account,
        bytes32 accountSalt,
        bytes memory verifierInitData
    ) internal virtual override returns (address) {
        (bool success, bytes memory returnData) = ZKSyncCreate2Factory(
            factory()
        ).deploy(
                accountSalt,
                proxyBytecodeHash,
                abi.encode(
                    guardianVerifierImplementation,
                    abi.encodeCall(
                        IGuardianVerifier.initialize,
                        (account, accountSalt, verifierInitData)
                    )
                )
            );
        require(success, "zksync deploy failed");
        address payable proxyAddress = abi.decode(returnData, (address));
        return proxyAddress;
    }
}
