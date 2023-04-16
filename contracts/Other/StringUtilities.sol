// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./string.sol";
import "hardhat/console.sol";

library StringUtils {
    using strings for string;
    using strings for strings.slice;

    function hash(string memory a) internal pure returns (bytes32) {
        return keccak256(abi.encode(a));
    }

    function contains(
        string memory a,
        string memory x
    ) internal pure returns (bool) {
        return a.toSlice().contains(x.toSlice());
    }

    function nameHash(string memory x) internal pure returns (uint256) {
        return uint256(hash(x));
    }

    function length(string memory x) internal pure returns (uint256) {
        return x.toSlice().len();
    }
}
