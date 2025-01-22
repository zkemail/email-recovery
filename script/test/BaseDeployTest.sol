// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

/* solhint-disable no-console */

import { console2 } from "forge-std/console2.sol";
import { Test } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ECDSAOwnedDKIMRegistry } from
    "@zk-email/ether-email-auth-contracts/src/utils/ECDSAOwnedDKIMRegistry.sol";
import { EmailAuth } from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import { EmailRecoveryCommandHandler } from "src/handlers/EmailRecoveryCommandHandler.sol";
import { EmailRecoveryFactory } from "src/factories/EmailRecoveryFactory.sol";
import { EmailRecoveryUniversalFactory } from "src/factories/EmailRecoveryUniversalFactory.sol";
import { Groth16Verifier } from "@zk-email/ether-email-auth-contracts/src/utils/Groth16Verifier.sol";
import { Verifier } from "@zk-email/ether-email-auth-contracts/src/utils/Verifier.sol";

abstract contract BaseDeployTest is Test {
    address internal constant CREATE2_DEPLOYER_ADDRESS = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    uint256 internal envPrivateKey;
    address internal envInitialOwner;
    address internal envVerifier;
    address internal envDkimSigner;
    address internal envDkimRegistry;
    uint256 internal envMinimumDelay;
    address internal envKillSwitchAuthorizer;
    address internal envEmailAuthImpl;
    address internal envNewOwner;
    address internal envValidator;
    uint256 internal envCreate2Salt;
    address internal envRecoveryFactory;

    /**
     * @dev Deploys needed contracts and sets environment vars.
     * @notice deploys the following contracts:
     * - verifier
     * - DKIM registry
     * - email auth implementation
     *
     */
    function setUp() public virtual {
        envPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        envInitialOwner = vm.addr(envPrivateKey);
        envVerifier = deployVerifier(envInitialOwner);
        envDkimSigner = vm.addr(5);
        envDkimRegistry = deployDKIMRegistry(envDkimSigner, envInitialOwner);
        envMinimumDelay = uint256(0);
        envKillSwitchAuthorizer = vm.addr(1);
        envEmailAuthImpl = address(new EmailAuth());
        envNewOwner = vm.addr(8);
        envValidator = vm.addr(9);
        envCreate2Salt = uint256(2);

        setAllEnvVars();
    }

    /**
     * @dev Helper function, sets all environment variables.
     * @notice Manual environment variable setting is performed at the beginning of each test:
     * If an environment variable is set using vm.setEnv() inside a test case, it sets the variable
     * for all test cases. Unfortunately, the setUp() function does not reset the environment
     * variables before each test case (despite having vm.setEnv() calls). Therefore, if a test case
     * modifies an environment variable, subsequent test cases will use the  modified value instead
     * of the one set in the setUp() function. For more details, see the closed GitHub issue:
     * https://github.com/foundry-rs/foundry/issues/2349
     */
    function setAllEnvVars() internal virtual {
        vm.setEnv("PRIVATE_KEY", vm.toString(envPrivateKey));
        vm.setEnv("VERIFIER", vm.toString(envVerifier));
        vm.setEnv("DKIM_SIGNER", vm.toString(envDkimSigner));
        vm.setEnv("DKIM_REGISTRY", vm.toString(envDkimRegistry));
        vm.setEnv("MINIMUM_DELAY", vm.toString(envMinimumDelay));
        vm.setEnv("KILL_SWITCH_AUTHORIZER", vm.toString(envKillSwitchAuthorizer));
        vm.setEnv("EMAIL_AUTH_IMPL", vm.toString(envEmailAuthImpl));
        vm.setEnv("NEW_OWNER", vm.toString(envNewOwner));
        vm.setEnv("VALIDATOR", vm.toString(envValidator));
        vm.setEnv("CREATE2_SALT", vm.toString(envCreate2Salt));
        vm.setEnv("RECOVERY_FACTORY", vm.toString(envRecoveryFactory));
    }

    /**
     * @dev Helper function, finds the event with the given signature hash in the logs array.
     * @param logs The array of Vm.Log structs.
     * @param eventSigHash The event signature hash (e.g. `keccak256("Event(address, uint256)"))`).
     * @return True if the event is found in the logs array; otherwise, false.
     */
    function findEvent(Vm.Log[] memory logs, bytes32 eventSigHash) internal pure returns (bool) {
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == eventSigHash) {
                return true;
            }
        }
        return false;
    }

    function computeAddress(
        uint256 salt,
        bytes memory bytecode,
        bytes memory constructorArgs,
        address deployer
    )
        internal
        pure
        returns (address)
    {
        bytes memory fullBytecode = abi.encodePacked(bytecode, constructorArgs);
        return Create2.computeAddress(bytes32(salt), keccak256(fullBytecode), deployer);
    }

    function computeAddress(
        uint256 salt,
        bytes memory bytecode,
        bytes memory constructorArgs
    )
        internal
        pure
        returns (address)
    {
        return computeAddress(salt, bytecode, constructorArgs, CREATE2_DEPLOYER_ADDRESS);
    }

    /**
     * @dev Deploys the Verifier contract and sets up its proxy.
     * @param initialOwner The address of the initial owner.
     * @return verifier The address of the deployed Verifier contract.
     */
    function deployVerifier(address initialOwner) internal returns (address verifier) {
        Verifier verifierImpl = new Verifier();
        Groth16Verifier groth16Verifier = new Groth16Verifier();
        ERC1967Proxy verifierProxy = new ERC1967Proxy(
            address(verifierImpl),
            abi.encodeCall(verifierImpl.initialize, (initialOwner, address(groth16Verifier)))
        );
        verifier = address(Verifier(address(verifierProxy)));
        return verifier;
    }

    /**
     * @dev Deploys the ECDSAOwnedDKIMRegistry contract and sets up its proxy.
     * @param dkimRegistrySigner The address of the DKIM registry signer.
     * @return The address of the deployed DKIM Registry contract.
     */
    function deployDKIMRegistry(
        address dkimRegistrySigner,
        address initialOwner
    )
        internal
        returns (address)
    {
        ECDSAOwnedDKIMRegistry dkimImpl = new ECDSAOwnedDKIMRegistry();
        console2.log("ECDSAOwnedDKIMRegistry implementation deployed at: %s", address(dkimImpl));
        ERC1967Proxy dkimProxy = new ERC1967Proxy(
            address(dkimImpl),
            abi.encodeCall(dkimImpl.initialize, (initialOwner, dkimRegistrySigner))
        );
        return address(ECDSAOwnedDKIMRegistry(address(dkimProxy)));
    }

    function deployRecoveryFactory() internal returns (address) {
        EmailRecoveryFactory recoveryFactory =
            new EmailRecoveryFactory{ salt: bytes32(envCreate2Salt) }(envVerifier, envEmailAuthImpl);
        return address(recoveryFactory);
    }

    function deployRecoveryUniversalFactory() internal returns (address) {
        EmailRecoveryUniversalFactory recoveryFactory = new EmailRecoveryUniversalFactory{
            salt: bytes32(envCreate2Salt)
        }(envVerifier, envEmailAuthImpl);
        return address(recoveryFactory);
    }
}
