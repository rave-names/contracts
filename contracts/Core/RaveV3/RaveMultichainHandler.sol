// SPDX-License-Identifier: GPLv3

pragma solidity ^0.8.19;

/*
 * RaveMultichainHandler
 *
 * This contract handles multichain RaveV3 interactions, through layerzero. This contract
 * should have NO STORAGE, and just relays write calls to the LZ endpoint.
 *
 */

import {SignatureVerifier} from "../../Other/SignatureVerifier.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ILayerZeroEndpoint} from "@layerzerolabs/solidity-examples/contracts/interfaces/ILayerZeroEndpoint.sol";
import {NonblockingLzAppUpgradeable as NBLA} from "@layerzerolabs/solidity-examples/contracts/contracts-upgradable/lzApp/NonblockingLzAppUpgradeable.sol";
import {IRavePriceFeed} from "./IRavePriceFeed.sol";
import {StringUtils} from "../../Other/StringUtilities.sol";
import {IRaveMultichainExtensionOracle} from "./IRaveMultichainExtensionOracle.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract RaveMultichainHandler is SignatureVerifier, UUPSUpgradeable, NBLA {
    using StringUtils for string;
    bytes32 internal key;
    IRavePriceFeed internal feed;
    address public transmitter;
    uint16 public transmitterChain;

    mapping(bytes32 extension => address price) public prices;

    function chainId() public view returns (uint256 id) {
        assembly {
            id := chainid()
        }
    }

    function initialize(
        string calldata feedKey,
        address _feed,
        address t,
        uint16 c
    ) external initializer {
        key = feedKey.hash();
        feed = IRavePriceFeed(_feed);
        transmitter = t;
        transmitterChain = c;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function _nonblockingLzReceive(
        uint16 chainId,
        bytes memory srcAddress,
        uint64 nonce,
        bytes memory payload
    ) internal override {}

    function registerName(
        string[] calldata names,
        string[] calldata extensions,
        address[] calldata resolvers,
        address[] calldata to,
        bytes32 message,
        bytes memory signature
    ) external payable {
        // this is data we send to the reciever contract, which decodes the signer from the signature,
        // the operation to perform, and sends that information to the hub, which acts accordingly.
        bytes memory data = abi.encode(
            message,
            signature,
            abi.encode(1, abi.encode(names, extensions, resolvers, to))
        );

        int nativePrice = feed.get(key);

        uint totalPrice = 0;

        for (uint i = 0; i < names.length; ++i) {
            require(
                prices[extensions[i].hash()] != address(0),
                string.concat(
                    "The name: ",
                    names[i],
                    ".",
                    extensions[i],
                    ", does not have a price oracle on chainId ",
                    Strings.toString(chainId())
                )
            );

            IRaveMultichainExtensionOracle(prices[extensions[i].hash()]).getUSDPrice(names[i].length());
        }
    }
}
