// Generated with the help of chat gpt - needed a quick solution to convert string to bytes32
library HexStrings {
    function fromHexString(string memory s) internal pure returns (bytes32 result) {
        bytes memory b = bytes(s);
        require(b.length == 66, "Invalid hex string length");
        require(b[0] == '0' && b[1] == 'x', "Invalid hex prefix");

        for (uint256 i = 0; i < 32; i++) {
            result |= bytes32(
                (uint256(uint8(fromHexChar(uint8(b[2 + i * 2]))) << 4) | uint256(uint8(fromHexChar(uint8(b[3 + i * 2])))))
            ) << (31 - i) * 8;
        }
    }

    function fromHexChar(uint8 c) internal pure returns (uint8) {
        if (bytes1(c) >= bytes1('0') && bytes1(c) <= bytes1('9')) {
            return c - uint8(bytes1('0'));
        }
        if (bytes1(c) >= bytes1('a') && bytes1(c) <= bytes1('f')) {
            return 10 + c - uint8(bytes1('a'));
        }
        if (bytes1(c) >= bytes1('A') && bytes1(c) <= bytes1('F')) {
            return 10 + c - uint8(bytes1('A'));
        }
        revert("Invalid hex character");
    }
}