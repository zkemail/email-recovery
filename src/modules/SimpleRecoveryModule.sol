pragma solidity ^0.8.12;

import { ERC7579ExecutorBase } from "@rhinestone/modulekit/src/Modules.sol";
import { IERC7579Account } from "erc7579/interfaces/IERC7579Account.sol";
import { SimpleGuardianManager } from "src/SimpleGuardianManager.sol";
import { SignatureVerifier } from "src/verifiers/SignatureVerifier.sol";
import { MockGroth16Verifier } from "src/test/MockGroth16Verifier.sol";
import { EmailProof } from "@zk-email/ether-email-auth-contracts/src/interfaces/IVerifier.sol";

contract SimpleRecoveryModule is ERC7579ExecutorBase {
    struct RecoveryConfig {
        bool activeRecovery;
        address manager;
        address verifiers;
    }

    mapping(address => RecoveryConfig) public recoveryConfigs;

    event RecoveryInitiated(address indexed account, uint256 timestamp);

    address public validator;

    SignatureVerifier public signatureVerifier;
    MockGroth16Verifier public groth16Verifier;

    constructor(address _validator, address _signatureVerifier, address _groth16Verifier) {
        validator = _validator;
        signatureVerifier = SignatureVerifier(_signatureVerifier);
        groth16Verifier = MockGroth16Verifier(_groth16Verifier);
    }

    function isRecoveryActive(address account) public view returns (bool) {
        return recoveryConfigs[account].activeRecovery;
    }

    function initiateRecovery(address account) public {
        require(!recoveryConfigs[account].activeRecovery, "Recovery is active");

        SimpleGuardianManager guardianManager =
            SimpleGuardianManager(recoveryConfigs[account].manager);

        recoveryConfigs[account].activeRecovery = true;

        uint256 recoveryId = guardianManager.initiateRecovery(account);

        emit RecoveryInitiated(account, block.timestamp);
    }

    function recover(address account, bytes calldata recoveryData, uint256 recoveryId) public {
        (, bytes memory recoveryCalldata) = abi.decode(recoveryData, (address, bytes));

        require(recoveryConfigs[account].activeRecovery, "Recovery is not active");

        SimpleGuardianManager guardianManager =
            SimpleGuardianManager(recoveryConfigs[account].manager);

        require(
            guardianManager.hasThresholdBeenMet(account, recoveryId), "Recovery threshold not met"
        );

        (address[] memory submitters, bytes[] memory proofs) =
            guardianManager.getSubmittedProofs(account, recoveryId);

        for (uint256 i = 0; i < proofs.length; i++) {
            require(proofs[i].length > 0, "Proof cannot be empty");

            (bytes1 proofType, bytes memory proof) = abi.decode(proofs[i], (bytes1, bytes));

            if (proofType == bytes1(0x00)) {
                (
                    string memory domainName,
                    bytes32 publicKeyHash,
                    uint256 timestamp,
                    string memory maskedCommand,
                    bytes32 emailNullifier,
                    bytes32 accountSalt,
                    bool isCodeExist,
                    bytes memory proof2
                ) = abi.decode(
                    proof, (string, bytes32, uint256, string, bytes32, bytes32, bool, bytes)
                );

                EmailProof memory emailProof2 = EmailProof(
                    domainName,
                    publicKeyHash,
                    timestamp,
                    maskedCommand,
                    emailNullifier,
                    accountSalt,
                    isCodeExist,
                    proof2
                );

                require(groth16Verifier.verifyEmailProof(emailProof2), "Invalid email proof");
            } else if (proofType == bytes1(0x01)) {
                (address signer, bytes32 messageHash, bytes memory signature) =
                    abi.decode(proof, (address, bytes32, bytes));

                require(
                    signatureVerifier.verifySignature(signer, messageHash, signature),
                    "Invalid signature"
                );
            } else {
                revert("Invalid proof type");
            }
        }

        _execute({ account: account, to: validator, value: 0, data: recoveryCalldata });

        recoveryConfigs[account].activeRecovery = false;
    }

    /**
     * @dev Helper function to slice bytes array.
     */
    function sliceBytes(
        bytes memory data,
        uint256 start,
        uint256 end
    )
        internal
        pure
        returns (bytes memory)
    {
        require(end > start && end <= data.length, "Invalid slice range");

        bytes memory result = new bytes(end - start);
        for (uint256 i = start; i < end; i++) {
            result[i - start] = data[i];
        }
        return result;
    }

    function isInitialized(address account) external view returns (bool) {
        return recoveryConfigs[account].manager != address(0);
    }

    /**
     * @notice Initializes the module with the guardianManager address, verifier addresses, and a
     * validation call
     * @dev This method sets up the recovery configuration mapping and ensures manager call succeeds
     * @param data Encoded data containing guardianManager, verifiers, and managerCallData
     */
    function onInstall(bytes calldata data) external {
        if (data.length == 0) revert();

        (bytes memory managerCallData, address guardianManager, address verifier) =
            abi.decode(data, (bytes, address, address));

        (bool success,) = guardianManager.call(managerCallData);
        if (!success) revert();

        if (
            !IERC7579Account(msg.sender).isModuleInstalled(
                TYPE_VALIDATOR, validator, managerCallData
            )
        ) {
            revert();
        }

        recoveryConfigs[msg.sender] =
            RecoveryConfig({ activeRecovery: false, manager: guardianManager, verifiers: verifier });
    }

    function onUninstall(bytes calldata /* data */ ) external {
        delete recoveryConfigs[msg.sender];
    }

    function updateRecoveryConfig(address guardianManager, address verifier) external {
        require(!recoveryConfigs[msg.sender].activeRecovery, "Recovery is active");
        recoveryConfigs[msg.sender].manager = guardianManager;
        recoveryConfigs[msg.sender].verifiers = verifier;
    }

    function name() external pure returns (string memory) {
        return "ZKEmail.SimpleRecoveryModule";
    }

    function version() external pure returns (string memory) {
        return "1.0.1";
    }

    function isModuleType(uint256 typeID) external pure returns (bool) {
        return typeID == TYPE_EXECUTOR;
    }
}
