// SPDX-License-Identifier: GPLv3

pragma solidity ^0.8.19;

interface IRavePriceFeed {
    function get(bytes32 key) external view returns (int256);
}
