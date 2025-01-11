// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "./DeploymentHelper.sol";

contract StructHelper is DeploymentHelper {

    //uint256[34] public pubSignals; <-- Defined in the DeploymentHelper.sol

    function buildEoaAuthMsg()
        public
        returns (EoaAuthMsg memory eoaAuthMsg)
    {
        bytes[] memory commandParams = new bytes[](2);
        commandParams[0] = abi.encode(1 ether);
        commandParams[1] = abi.encode(
            "0x0000000000000000000000000000000000000020"
        );

        EoaProof memory eoaProof = EoaProof({
            //publicKeyHash: publicKeyHash,
            publicKeyHash: _publicKeyHash,
            timestamp: 1694989812,
            eoaNullifier: eoaNullifier,
            proof: mockProof /// @dev - [NOTE]: bytes mockProof = abi.encodePacked(bytes1(0x01));
        });

        eoaAuthMsg = EoaAuthMsg({
            proof: eoaProof
        });

        vm.mockCall(
            address(verifier),
            abi.encodeCall(Verifier.verifyEoaProof, (eoaProof, pubSignals)),
            abi.encode(true)
        );
    }
}
