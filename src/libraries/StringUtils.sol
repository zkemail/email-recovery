// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "solidity-stringutils/src/strings.sol";

// Extracted from https://github.com/zkemail/email-wallet-sdk/blob/main/src/helpers/StringUtils.sol
library StringUtils {
    using strings for *;

    function hexToBytes32(string calldata hexStr) public pure returns (bytes32 result) {
        require(hexStr.toSlice().startsWith("0x".toSlice()), "invalid hex prefix");
        hexStr = hexStr[2:];
        require(bytes(hexStr).length == 64, "invalid hex string length");
        uint256[] memory ints = hex2Ints(hexStr);
        uint256 sum = 0;
        for (uint256 i = 0; i < 32; i++) {
            sum = (256 * sum + ints[i]);
        }
        return bytes32(sum);
    }

    function hex2Ints(string memory hexStr) private pure returns (uint256[] memory) {
        uint256[] memory result = new uint256[](bytes(hexStr).length / 2);
        for (uint256 i = 0; i < result.length; i++) {
            result[i] =
                16 * hexChar2Int(bytes(hexStr)[2 * i]) + hexChar2Int(bytes(hexStr)[2 * i + 1]);
        }
        return result;
    }

    function hexChar2Int(bytes1 char) private pure returns (uint256) {
        uint8 charInt = uint8(char);
        if (charInt >= 48 && charInt <= 57) {
            return charInt - 48;
        } else if (charInt >= 97 && charInt <= 102) {
            return charInt - 87;
        } else {
            require(false, "invalid hex char");
        }
        return 0;
    }
}
