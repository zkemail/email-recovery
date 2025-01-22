// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

/* solhint-disable no-console */

import { console2 } from "forge-std/console2.sol";
import { Test } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { BaseDeployScript } from "../BaseDeployScript.s.sol";
import { ECDSAOwnedDKIMRegistry } from
    "@zk-email/ether-email-auth-contracts/src/utils/ECDSAOwnedDKIMRegistry.sol";
import { EmailAuth } from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import { Groth16Verifier } from "@zk-email/ether-email-auth-contracts/src/utils/Groth16Verifier.sol";
import { Verifier } from "@zk-email/ether-email-auth-contracts/src/utils/Verifier.sol";
import { UserOverrideableDKIMRegistry } from "@zk-email/contracts/UserOverrideableDKIMRegistry.sol";
import { EmailRecoveryCommandHandler } from "src/handlers/EmailRecoveryCommandHandler.sol";

abstract contract BaseDeployTest is Test {
    // Forge deterministic deployer address. See more details in the Foundry book:
    // https://book.getfoundry.sh/tutorials/create2-tutorial#introduction
    address internal constant CREATE2_DEPLOYER_ADDRESS = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    uint256 internal envPrivateKey;
    address internal envInitialOwner;
    address internal envVerifier;
    address internal envDkimSigner;
    address internal envDkimRegistry;
    uint256 internal envDkimDelay;
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
        envDkimDelay = 0;
        envMinimumDelay = 0;
        envKillSwitchAuthorizer = vm.addr(1);
        envEmailAuthImpl = address(new EmailAuth());
        envNewOwner = vm.addr(8);
        envValidator = vm.addr(9);
        envCreate2Salt = 2;

        setAllEnvVars();
    }

    /**
     * @dev Function that sets all environment variables from the contract state.
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
        vm.setEnv("DKIM_DELAY", vm.toString(envDkimDelay));
        vm.setEnv("MINIMUM_DELAY", vm.toString(envMinimumDelay));
        vm.setEnv("KILL_SWITCH_AUTHORIZER", vm.toString(envKillSwitchAuthorizer));
        vm.setEnv("EMAIL_AUTH_IMPL", vm.toString(envEmailAuthImpl));
        vm.setEnv("NEW_OWNER", vm.toString(envNewOwner));
        vm.setEnv("VALIDATOR", vm.toString(envValidator));
        vm.setEnv("CREATE2_SALT", vm.toString(envCreate2Salt));
        vm.setEnv("RECOVERY_FACTORY", vm.toString(envRecoveryFactory));
    }

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

    // ### HELPER FUNCTIONS ###
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

    /**
     * @dev Helper function, computes the address of a contract deployed using a custom CREATE2
     * deployer.
     * @param create2Salt The salt used in the CREATE2 deployment.
     * @param creationCode The contract's creation code. - `type(Contract).creationCode`
     * @param constructorArgs The contract's constructor arguments. - `abi.encode(a1, a2, ...)`
     * @param deployer The address of the deployer.
     */
    function computeAddress(
        uint256 create2Salt,
        bytes memory creationCode,
        bytes memory constructorArgs,
        address deployer
    )
        internal
        pure
        returns (address)
    {
        bytes memory fullBytecode = abi.encodePacked(creationCode, constructorArgs);
        return Create2.computeAddress(bytes32(create2Salt), keccak256(fullBytecode), deployer);
    }

    /**
     * @dev Helper function, computes the address of a contract deployed using the default CREATE2
     * deployer.
     * @param create2Salt The salt used in the CREATE2 deployment.
     * @param creationCode The contract's creation code. - `type(Contract).creationCode`
     * @param constructorArgs The contract's constructor arguments. - `abi.encode(a1, a2, ...)`
     */
    function computeAddress(
        uint256 create2Salt,
        bytes memory creationCode,
        bytes memory constructorArgs
    )
        internal
        pure
        returns (address)
    {
        return computeAddress(create2Salt, creationCode, constructorArgs, CREATE2_DEPLOYER_ADDRESS);
    }

    /**
     * @dev Helper function, checks if a contract is deployed at the given address.
     * @param addr The address to check.
     * @return True if a contract is deployed at the given address; otherwise, false.
     */
    function isContractDeployed(address addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }

    // ### COMMON TEST FUNCTIONS ###
    function commonTest_RevertIf_NoPrivateKeyEnv(BaseDeployScript target) public {
        vm.setEnv("PRIVATE_KEY", "");
        vm.expectRevert(
            "vm.envUint: failed parsing $PRIVATE_KEY as type `uint256`: missing hex prefix (\"0x\") for hex string"
        );
        target.run();
    }

    function commonTest_RevertIf_NoKillSwitchAuthorizerEnv(BaseDeployScript target) public {
        vm.setEnv("KILL_SWITCH_AUTHORIZER", "");
        vm.expectRevert(
            "vm.envAddress: failed parsing $KILL_SWITCH_AUTHORIZER as type `address`: parser error:\n$KILL_SWITCH_AUTHORIZER\n^\nexpected hex digits or the `0x` prefix for an empty hex string"
        );
        target.run();
    }

    function commonTest_RevertIf_NoDkimRegistryAndSignerEnvs(BaseDeployScript target) public {
        vm.setEnv("DKIM_REGISTRY", "");
        vm.setEnv("DKIM_SIGNER", "");

        vm.expectRevert("DKIM_REGISTRY or DKIM_SIGNER is required");
        target.run();
    }

    function commonTest_DeploymentEvent(
        BaseDeployScript target,
        bytes memory eventSignature
    )
        public
    {
        vm.recordLogs();
        target.run();

        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertTrue(findEvent(entries, keccak256(eventSignature)), "deploy event not emitted");
    }

    function commonTest_NoVerifierEnv(BaseDeployScript target) public {
        vm.setEnv("VERIFIER", "");

        address verifier = computeAddress(envCreate2Salt, type(Verifier).creationCode, "");
        address groth16 = computeAddress(envCreate2Salt, type(Groth16Verifier).creationCode, "");
        address proxy = computeAddress(
            envCreate2Salt,
            type(ERC1967Proxy).creationCode,
            abi.encode(
                verifier,
                abi.encodeCall(Verifier(verifier).initialize, (envInitialOwner, address(groth16)))
            )
        );

        require(!isContractDeployed(proxy), "verifier should not be deployed yet");
        target.run();
        require(isContractDeployed(proxy), "verifier should be deployed");
    }

    function commonTest_NoZkVerifierEnv(BaseDeployScript target) public {
        vm.setEnv("ZK_VERIFIER", "");

        address zkVerifier = computeAddress(envCreate2Salt, type(Verifier).creationCode, "");
        address groth16 = computeAddress(envCreate2Salt, type(Groth16Verifier).creationCode, "");
        address proxy = computeAddress(
            envCreate2Salt,
            type(ERC1967Proxy).creationCode,
            abi.encode(
                zkVerifier,
                abi.encodeCall(Verifier(zkVerifier).initialize, (envInitialOwner, address(groth16)))
            )
        );

        require(!isContractDeployed(proxy), "zk verifier should not be deployed yet");
        target.run();
        require(isContractDeployed(proxy), "zk verifier should be deployed");
    }

    function commonTest_NoDkimRegistryEnv(BaseDeployScript target) public {
        vm.setEnv("DKIM_REGISTRY", "");

        address dkim =
            computeAddress(envCreate2Salt, type(UserOverrideableDKIMRegistry).creationCode, "");
        address proxy = computeAddress(
            envCreate2Salt,
            type(ERC1967Proxy).creationCode,
            abi.encode(
                dkim,
                abi.encodeCall(
                    UserOverrideableDKIMRegistry(dkim).initialize,
                    (envInitialOwner, envDkimSigner, envDkimDelay)
                )
            )
        );

        require(!isContractDeployed(proxy), "dkim registry should not be deployed yet");
        target.run();
        require(isContractDeployed(proxy), "verifier should be deployed");
    }

    function commonTest_NoEmailAuthImplEnv(BaseDeployScript target) public {
        vm.setEnv("EMAIL_AUTH_IMPL", "");

        address emailAuthImpl = computeAddress(envCreate2Salt, type(EmailAuth).creationCode, "");

        require(!isContractDeployed(emailAuthImpl), "email auth impl should not be deployed yet");
        target.run();
        require(isContractDeployed(emailAuthImpl), "email auth impl should be deployed");
    }
}
