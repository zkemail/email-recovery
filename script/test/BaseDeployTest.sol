// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console */

import { console2 } from "forge-std/console2.sol";
import { Test } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { BaseDeployScript } from "../BaseDeploy.s.sol";
import { ECDSAOwnedDKIMRegistry } from
    "@zk-email/ether-email-auth-contracts/src/utils/ECDSAOwnedDKIMRegistry.sol";
import { EmailAuth } from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import { Groth16Verifier } from "@zk-email/ether-email-auth-contracts/src/utils/Groth16Verifier.sol";
import { Verifier } from "@zk-email/ether-email-auth-contracts/src/utils/Verifier.sol";
import { UserOverrideableDKIMRegistry } from "@zk-email/contracts/UserOverrideableDKIMRegistry.sol";

abstract contract BaseDeployTest is Test {
    // Forge deterministic deployer address. See more details in the Foundry book:
    // https://book.getfoundry.sh/tutorials/create2-tutorial#introduction
    address internal constant CREATE2_DEPLOYER_ADDRESS = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    BaseDeployScript.DeploymentConfig public config;

    /**
     * @dev Deploys needed contracts and sets environment vars.
     * @notice deploys the following contracts:
     * - verifier
     * - DKIM registry
     * - email auth implementation
     *
     */
    function setUp() public virtual {
        uint256 privateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        address dkimSigner = vm.addr(5);
        address initialOwner = vm.addr(privateKey);

        config = BaseDeployScript.DeploymentConfig({
            create2Salt: bytes32(uint256(2)),
            dkimDelay: 0,
            minimumDelay: 0,
            privateKey: privateKey,
            dkimRegistry: deployDKIMRegistry(dkimSigner, initialOwner),
            dkimSigner: dkimSigner,
            emailAuthImpl: address(new EmailAuth()),
            killSwitchAuthorizer: vm.addr(1),
            recoveryFactory: address(0),
            verifier: deployVerifier(initialOwner),
            zkVerifier: address(0),
            commandHandler: address(0),
            validator: vm.addr(9)
        });

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
        vm.setEnv("PRIVATE_KEY", vm.toString(config.privateKey));
        vm.setEnv("VERIFIER", vm.toString(config.verifier));
        vm.setEnv("DKIM_SIGNER", vm.toString(config.dkimSigner));
        vm.setEnv("DKIM_REGISTRY", vm.toString(config.dkimRegistry));
        vm.setEnv("DKIM_DELAY", vm.toString(config.dkimDelay));
        vm.setEnv("MINIMUM_DELAY", vm.toString(config.minimumDelay));
        vm.setEnv("KILL_SWITCH_AUTHORIZER", vm.toString(config.killSwitchAuthorizer));
        vm.setEnv("EMAIL_AUTH_IMPL", vm.toString(config.emailAuthImpl));
        vm.setEnv("VALIDATOR", vm.toString(config.validator));
        vm.setEnv("CREATE2_SALT", vm.toString(config.create2Salt));
        vm.setEnv("RECOVERY_FACTORY", vm.toString(config.recoveryFactory));
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
        bytes32 create2Salt,
        bytes memory creationCode,
        bytes memory constructorArgs,
        address deployer
    )
        internal
        pure
        returns (address)
    {
        bytes memory fullBytecode = abi.encodePacked(creationCode, constructorArgs);
        return Create2.computeAddress(create2Salt, keccak256(fullBytecode), deployer);
    }

    /**
     * @dev Helper function, computes the address of a contract deployed using the default CREATE2
     * deployer.
     * @param create2Salt The salt used in the CREATE2 deployment.
     * @param creationCode The contract's creation code. - `type(Contract).creationCode`
     * @param constructorArgs The contract's constructor arguments. - `abi.encode(a1, a2, ...)`
     */
    function computeAddress(
        bytes32 create2Salt,
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
        /* solhint-disable-next-line no-inline-assembly */
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }

    // ### COMMON TEST FUNCTIONS ###
    function commonTest_RevertIf_NoPrivateKeyEnv(BaseDeployScript target) public {
        vm.setEnv("PRIVATE_KEY", "");
        vm.expectRevert(
            abi.encodeWithSelector(
                BaseDeployScript.MissingRequiredParameter.selector, "PRIVATE_KEY"
            )
        );
        target.run();
    }

    function commonTest_RevertIf_NoKillSwitchAuthorizerEnv(BaseDeployScript target) public {
        vm.setEnv("KILL_SWITCH_AUTHORIZER", "");
        vm.expectRevert(
            abi.encodeWithSelector(
                BaseDeployScript.MissingRequiredParameter.selector, "KILL_SWITCH_AUTHORIZER"
            )
        );
        target.run();
    }

    function commonTest_RevertIf_NoDkimRegistryAndSignerEnvs(BaseDeployScript target) public {
        vm.setEnv("DKIM_REGISTRY", "");
        vm.setEnv("DKIM_SIGNER", "");

        vm.expectRevert(
            abi.encodeWithSelector(
                BaseDeployScript.MissingRequiredParameter.selector, "DKIM_REGISTRY/DKIM_SIGNER"
            )
        );
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

        address initialOwner = vm.addr(config.privateKey);

        address verifier = computeAddress(config.create2Salt, type(Verifier).creationCode, "");
        address groth16 = computeAddress(config.create2Salt, type(Groth16Verifier).creationCode, "");
        address proxy = computeAddress(
            config.create2Salt,
            type(ERC1967Proxy).creationCode,
            abi.encode(
                verifier,
                abi.encodeCall(Verifier(verifier).initialize, (initialOwner, address(groth16)))
            )
        );

        assert(!isContractDeployed(proxy));
        target.run();
        assert(isContractDeployed(proxy));
    }

    function commonTest_NoZkVerifierEnv(BaseDeployScript target) public {
        vm.setEnv("ZK_VERIFIER", "");

        address initialOwner = vm.addr(config.privateKey);

        address zkVerifier = computeAddress(config.create2Salt, type(Verifier).creationCode, "");
        address groth16 = computeAddress(config.create2Salt, type(Groth16Verifier).creationCode, "");
        address proxy = computeAddress(
            config.create2Salt,
            type(ERC1967Proxy).creationCode,
            abi.encode(
                zkVerifier,
                abi.encodeCall(Verifier(zkVerifier).initialize, (initialOwner, address(groth16)))
            )
        );

        assert(!isContractDeployed(proxy));
        target.run();
        assert(isContractDeployed(proxy));
    }

    function commonTest_NoDkimRegistryEnv(BaseDeployScript target) public {
        vm.setEnv("DKIM_REGISTRY", "");

        address initialOwner = vm.addr(config.privateKey);

        address dkim =
            computeAddress(config.create2Salt, type(UserOverrideableDKIMRegistry).creationCode, "");
        address proxy = computeAddress(
            config.create2Salt,
            type(ERC1967Proxy).creationCode,
            abi.encode(
                dkim,
                abi.encodeCall(
                    UserOverrideableDKIMRegistry(dkim).initialize,
                    (initialOwner, config.dkimSigner, config.dkimDelay)
                )
            )
        );

        assert(!isContractDeployed(proxy));
        target.run();
        assert(isContractDeployed(proxy));
    }

    function commonTest_NoEmailAuthImplEnv(BaseDeployScript target) public {
        vm.setEnv("EMAIL_AUTH_IMPL", "");

        address emailAuthImpl = computeAddress(config.create2Salt, type(EmailAuth).creationCode, "");

        assert(!isContractDeployed(emailAuthImpl));
        target.run();
        assert(isContractDeployed(emailAuthImpl));
    }
}
