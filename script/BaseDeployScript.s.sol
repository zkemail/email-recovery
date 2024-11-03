// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console, gas-custom-errors */

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { Verifier } from "@zk-email/ether-email-auth-contracts/src/utils/Verifier.sol";
import { Groth16Verifier } from "@zk-email/ether-email-auth-contracts/src/utils/Groth16Verifier.sol";
import { UserOverrideableDKIMRegistry } from "@zk-email/contracts/UserOverrideableDKIMRegistry.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract BaseDeployScript is Script {
    function run() public virtual { }

    /**
     * Helper function to deploy a Verifier
     */
    function deployVerifier(address initialOwner, uint256 salt) public returns (address) {
        Verifier verifierImpl = new Verifier{ salt: bytes32(salt) }();
        console.log("Verifier implementation deployed at: %s", address(verifierImpl));
        Groth16Verifier groth16Verifier = new Groth16Verifier{ salt: bytes32(salt) }();
        ERC1967Proxy verifierProxy = new ERC1967Proxy{ salt: bytes32(salt) }(
            address(verifierImpl),
            abi.encodeCall(verifierImpl.initialize, (initialOwner, address(groth16Verifier)))
        );
        address verifier = address(Verifier(address(verifierProxy)));
        console.log("Deployed Verifier at", verifier);
        return verifier;
    }

    /**
     * Helper function to deploy a UserOverrideableDKIMRegistry
     */
    function deployUserOverrideableDKIMRegistry(
        address initialOwner,
        address dkimRegistrySigner,
        uint256 setTimeDelay,
        uint256 salt
    )
        public
        returns (address)
    {
        require(dkimRegistrySigner != address(0), "DKIM_SIGNER is required");
        UserOverrideableDKIMRegistry overrideableDkimImpl =
            new UserOverrideableDKIMRegistry{ salt: bytes32(salt) }();
        console.log(
            "UserOverrideableDKIMRegistry implementation deployed at: %s",
            address(overrideableDkimImpl)
        );
        ERC1967Proxy dkimProxy = new ERC1967Proxy{ salt: bytes32(salt) }(
            address(overrideableDkimImpl),
            abi.encodeCall(
                overrideableDkimImpl.initialize, (initialOwner, dkimRegistrySigner, setTimeDelay)
            )
        );
        address dkim = address(dkimProxy);
        console.log("UseroverrideableDKIMRegistry proxy deployed at: %s", dkim);
        return dkim;
    }
}
