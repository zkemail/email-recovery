// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

library SubjectCalldataBuilder {

    // subjectParams MUST be abi.encoded otherwise calldata contruction will fail. This is particulary important for dynamic types which have their length encoded
    function buildSubjectCalldata(bytes[] memory subjectParams) internal returns (bytes memory) {
        // TODO: store this dynamically
        bytes4 functionSelector = bytes4(keccak256(bytes("changeOwner(address,address,address)")));

        if (subjectParamsLength == 1) {
            return abi.encodePacked(functionSelector, subjectParams[0]);
        }

        if (subjectParamsLength == 2) {
            return abi.encodePacked(functionSelector, subjectParams[0], subjectParams[1]);
        }

        if (subjectParamsLength == 3) {
            return abi.encodePacked(functionSelector, subjectParams[0], subjectParams[1], subjectParams[2]);
        }

        if (subjectParamsLength == 4) {
            return abi.encodePacked(functionSelector, subjectParams[0], subjectParams[1], subjectParams[2], subjectParams[3]);
        }

        revert("TODO: implement more");
    }
}