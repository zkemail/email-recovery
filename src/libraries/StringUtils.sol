// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { strings } from "solidity-stringutils/src/strings.sol";

/* solhint-disable gas-custom-errors */

/**
 * @title StringUtils
 * @notice This library provides utility functions for converting hexadecimal strings to bytes32.
 * @dev Extracted from
 * https://github.com/zkemail/email-wallet-sdk/blob/main/src/helpers/StringUtils.sol
 */
library StringUtils {
    using strings for *;

    /**
     * @notice Converts a hexadecimal string to bytes32
     * @dev The input string must start with "0x" and be 66 characters long (including "0x")
     * @param hexStr The hexadecimal string to convert
     * @return result The converted bytes32 value
     */
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

    /**
     * @notice Converts a hexadecimal string to an array of integers
     * @dev Each pair of characters in the input string is converted to a single integer
     * @param hexStr The hexadecimal string to convert
     * @return uint256[] An array of integers representing the converted hexadecimal string
     */
    function hex2Ints(string memory hexStr) private pure returns (uint256[] memory) {
        uint256[] memory result = new uint256[](bytes(hexStr).length / 2);
        for (uint256 i = 0; i < result.length; i++) {
            result[i] =
                16 * hexChar2Int(bytes(hexStr)[2 * i]) + hexChar2Int(bytes(hexStr)[2 * i + 1]);
        }
        return result;
    }

    /**
     * @notice Converts a single hexadecimal character to its integer representation
     * @dev Supports lowercase hexadecimal characters
     * @param char The hexadecimal character to convert
     * @return uint256 The integer representation of the hexadecimal character
     */
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
