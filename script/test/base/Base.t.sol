// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console */

import { console2 } from "forge-std/console2.sol";
import { Test } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ECDSAOwnedDKIMRegistry } from
    "@zk-email/ether-email-auth-contracts/src/utils/ECDSAOwnedDKIMRegistry.sol";
import { EmailAuth } from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import { Groth16Verifier } from "@zk-email/ether-email-auth-contracts/src/utils/Groth16Verifier.sol";
import { Verifier } from "@zk-email/ether-email-auth-contracts/src/utils/Verifier.sol";
import { BaseDeployScript } from "script/base/BaseDeploy.s.sol";

abstract contract BaseTest is Test {
    // Forge deterministic deployer address. See more details in the Foundry book:
    // https://book.getfoundry.sh/tutorials/create2-tutorial#introduction
    address internal constant CREATE2_DEPLOYER_ADDRESS = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    BaseDeployScript.DeploymentConfig internal config;

    function setUp() public virtual {
        uint256 privateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        address dkimSigner = vm.addr(5);
        address initialOwner = vm.addr(privateKey);

        config = BaseDeployScript.DeploymentConfig({
            create2Salt: bytes32(uint256(2)),
            dkimDelay: 0,
            minimumDelay: 0,
            privateKey: privateKey,
            dkimRegistry: deployDkimRegistry(dkimSigner, initialOwner),
            dkimSigner: dkimSigner,
            emailAuthImpl: deployEmailAuthImpl(),
            killSwitchAuthorizer: vm.addr(1),
            recoveryFactory: address(0),
            verifier: deployVerifier(initialOwner),
            zkVerifier: deployVerifier(initialOwner),
            commandHandler: address(0),
            validator: vm.addr(9)
        });

        setAllEnvVars();
    }

    // ### PRIVATE HELPER FUNCTIONS ###

    /**
     * @dev Helper function, deploys a Verifier contract and a Groth16Verifier contract, and then
     * deploys a proxy contract for it.
     * @param initialOwner The initial owner of the Verifier contract.
     * @return proxy The address of the Verifier proxy contract.
     */
    function deployVerifier(address initialOwner) private returns (address proxy) {
        address verifier = address(new Verifier());
        console2.log("Deployed Verifier implementation at: %s", address(verifier));

        address groth16 = address(new Groth16Verifier());
        console2.log("Deployed Groth16Verifier implementation at: %s", groth16);

        proxy = address(
            new ERC1967Proxy(
                verifier, abi.encodeCall(Verifier(verifier).initialize, (initialOwner, groth16))
            )
        );
        console2.log("Deployed Verifier proxy at: %s", proxy);
    }

    /**
     * @dev Helper function, deploys a ECDSAOwnedDKIMRegistry contract and then deploys a
     * proxy contract for it.
     * @param dkimSigner The DKIM signer address.
     * @param initialOwner The initial owner of the ECDSAOwnedDKIMRegistry contract.
     * @return proxy The address of the ECDSAOwnedDKIMRegistry proxy contract.
     */
    function deployDkimRegistry(
        address dkimSigner,
        address initialOwner
    )
        private
        returns (address proxy)
    {
        address dkim = address(new ECDSAOwnedDKIMRegistry());
        console2.log("ECDSAOwnedDKIMRegistry implementation deployed at: %s", dkim);

        proxy = address(
            new ERC1967Proxy(
                address(dkim),
                abi.encodeCall(ECDSAOwnedDKIMRegistry(dkim).initialize, (initialOwner, dkimSigner))
            )
        );
        console2.log("ECDSAOwnedDKIMRegistry proxy deployed at: %s", proxy);
    }

    /**
     * @dev Helper function, deploys an EmailAuth contract.
     * @return emailAuthImpl The address of the EmailAuth contract.
     */
    function deployEmailAuthImpl() private returns (address emailAuthImpl) {
        emailAuthImpl = address(new EmailAuth());
        console2.log("Deployed Email Auth at", emailAuthImpl);
    }

    // ### INTERNAL HELPER FUNCTIONS ###

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
        vm.setEnv("CREATE2_SALT", vm.toString(config.create2Salt));
        vm.setEnv("DKIM_DELAY", vm.toString(config.dkimDelay));
        vm.setEnv("MINIMUM_DELAY", vm.toString(config.minimumDelay));
        vm.setEnv("PRIVATE_KEY", vm.toString(config.privateKey));
        vm.setEnv("COMMAND_HANDLER", vm.toString(config.commandHandler));
        vm.setEnv("DKIM_REGISTRY", vm.toString(config.dkimRegistry));
        vm.setEnv("DKIM_SIGNER", vm.toString(config.dkimSigner));
        vm.setEnv("EMAIL_AUTH_IMPL", vm.toString(config.emailAuthImpl));
        vm.setEnv("KILL_SWITCH_AUTHORIZER", vm.toString(config.killSwitchAuthorizer));
        vm.setEnv("RECOVERY_FACTORY", vm.toString(config.recoveryFactory));
        vm.setEnv("VALIDATOR", vm.toString(config.validator));
        vm.setEnv("VERIFIER", vm.toString(config.verifier));
        vm.setEnv("ZK_VERIFIER", vm.toString(config.zkVerifier));
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
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }
}
