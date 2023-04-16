// SPDX-License-Identifier: GPLv3

pragma solidity ^0.8.19;

import {IRavePriceFeed} from "./IRavePriceFeed.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {StringUtils} from "../../Other/StringUtilities.sol";

contract RavePriceFeed is IRavePriceFeed, Ownable {
    mapping(bytes32 => AggregatorV3Interface) internal feeds;

    using StringUtils for string;

    event AddFeed(address indexed _address, bytes32 indexed id);

    constructor() {
        /*
            Fantom, FTM/USD
         */
        feeds[string("FTMUSD").hash()] = AggregatorV3Interface(
            0xf4766552D15AE4d256Ad41B6cf2933482B0680dc
        );
    }

    function get(bytes32 key) external view returns (int256) {
        (, int price, , , ) = feeds[key].latestRoundData();

        return price;
    }

    function addFeed(address _address, string calldata key) external onlyOwner {
        feeds[key.hash()] = AggregatorV3Interface(_address);
        emit AddFeed(_address, key.hash());
    }
}
