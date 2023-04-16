// SPDX-License-Identifier: GPLv3

pragma solidity ^0.8.19;

interface IRaveMultichainExtensionOracle {
    function getUSDPrice(uint characters) external view returns (uint);

    function getRenewPrice(
        uint chatacters,
        uint time
    ) external view returns (uint);

    function getPayee() external view returns (address);
}
