// SPDX-License-Identifier: GPLv3

/*
 * This is a contract to mock the functionality of a price feed
 */

pragma solidity ^0.8.19;

import {IRavePriceFeed} from "../IRavePriceFeed.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {StringUtils} from "../../../Other/StringUtilities.sol";

contract RavePriceFeed is IRavePriceFeed, Ownable {
    mapping(bytes32 => int) internal feeds;

    using StringUtils for string;

    event AddFeed(address indexed _address, int id);

    constructor() {
        /*
            Fantom, FTM/USD
         */
        feeds[string("FTMUSD").hash()] = int(1) / 10;
    }

    function get(bytes32 key) external view returns (int256) {
        int price = feeds[key];

        return price;
    }

    function addFeed(address, string calldata key) external onlyOwner {
        feeds[key.hash()] = int(1) / 10;
    }
}
