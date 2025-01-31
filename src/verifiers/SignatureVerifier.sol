// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

contract SignatureVerifier {
    
    function verifySignature(
        address signer,
        bytes32 messageHash,
        bytes memory signature
    ) public pure returns (bool) {
        require(signer != address(0), "Invalid signer address");
        
        
        return recoverSigner(messageHash, signature) == signer;
    }
    
    
    function recoverSigner(bytes32 ethSignedMessageHash, bytes memory signature) public pure returns (address) {
        require(signature.length == 65, "Invalid signature length");
        
        bytes32 r;
        bytes32 s;
        uint8 v;
        
        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }
        
        require(v == 27 || v == 28, "Invalid signature version");
        
        return ecrecover(ethSignedMessageHash, v, r, s);
    }
}
