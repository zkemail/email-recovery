// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console, gas-custom-errors */

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { Verifier } from "@zk-email/ether-email-auth-contracts/src/utils/Verifier.sol";
import { Groth16Verifier } from "@zk-email/ether-email-auth-contracts/src/utils/Groth16Verifier.sol";
import { UserOverrideableDKIMRegistry } from "@zk-email/contracts/UserOverrideableDKIMRegistry.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { SafeSingletonDeployer } from "safe-singleton-deployer/SafeSingletonDeployer.sol";

contract BaseDeployScript is Script {
    function run() public virtual { }

    /**
     * Helper function to deploy a Verifier
     */
    function deployVerifier(address initialOwner, uint256) public returns (address) {
        address verifierImpl = SafeSingletonDeployer.deploy(
            type(Verifier).creationCode, abi.encode(), keccak256("VERIFIER")
        );
        console.log("Verifier implementation deployed at: %s", address(verifierImpl));

        address groth16Verifier = SafeSingletonDeployer.deploy(
            type(Groth16Verifier).creationCode, abi.encode(), keccak256("GROTH16_VERIFIER")
        );

        address verifierProxy = SafeSingletonDeployer.deploy(
            type(ERC1967Proxy).creationCode,
            abi.encode(
                address(verifierImpl),
                abi.encodeCall(Verifier(verifierImpl).initialize, (initialOwner, groth16Verifier))
            ),
            keccak256("VERIFIER_PROXY")
        );

        console.log("Deployed Verifier at", verifierProxy);
        return verifierProxy;
    }

    /**
     * Helper function to deploy a UserOverrideableDKIMRegistry
     */
    function deployUserOverrideableDKIMRegistry(
        address initialOwner,
        address dkimRegistrySigner,
        uint256 setTimeDelay,
        uint256
    )
        public
        returns (address)
    {
        require(dkimRegistrySigner != address(0), "DKIM_SIGNER is required");

        address impl = SafeSingletonDeployer.deploy(
            type(UserOverrideableDKIMRegistry).creationCode,
            abi.encode(),
            keccak256("USER_OVERRIDEABLE_DKIM_IMPL")
        );
        console.log("UserOverrideableDKIMRegistry implementation deployed at: %s", address(impl));

        address proxy = SafeSingletonDeployer.deploy(
            type(ERC1967Proxy).creationCode,
            abi.encode(
                address(impl),
                abi.encodeCall(
                    UserOverrideableDKIMRegistry(impl).initialize,
                    (initialOwner, dkimRegistrySigner, setTimeDelay)
                )
            ),
            keccak256("USER_OVERRIDEABLE_DKIM_PROXY")
        );

        console.log("UseroverrideableDKIMRegistry proxy deployed at: %s", proxy);
        return proxy;
    }
}
