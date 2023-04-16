// SPDX-License-Identifier: GPLv3

pragma solidity ^0.8.19;

/*
 * This is the Rave Multichain Oracle.
 *
 * It just tells the Multichain Handler what the prices of some operations are.
 */

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IRaveMultichainExtensionOracle as IOracle} from "./IRaveMultichainExtensionOracle.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract RaveV3BasicMultichainOracle is
    UUPSUpgradeable,
    IOracle,
    OwnableUpgradeable
{
    function _authorizeUpgrade(address) internal override onlyOwner {}

    function getUSDPrice(uint) external pure returns (uint) {
        return 5;
    }

    function getRenewPrice(uint, uint) external pure returns (uint) {
        return 0;
    }

    function getPayee() external pure returns (address) {
        return address(0);
    }
}
