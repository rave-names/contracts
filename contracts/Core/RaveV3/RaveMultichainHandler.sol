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

    struct MsgSig {
        bytes32 message;
        bytes signature;
    }

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

    function recoverDust() external onlyOwner {
        owner().call{value: address(this).balance}("");
    }

    function registerName(
        string[] memory names,
        string[] memory extensions,
        address[] memory resolvers,
        address[] memory to
    ) external payable {
        // this is data we send to the reciever contract, which decodes the signer from the signature,
        // the operation to perform, and sends that information to the hub, which acts accordingly.
        bytes memory data = abi.encode(
            msg.sender,
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

            totalPrice +=
                IRaveMultichainExtensionOracle(prices[extensions[i].hash()])
                    .getUSDPrice(names[i].length()) *
                uint256(nativePrice);
        }

        (uint minFee, ) = lzEndpoint.estimateFees(
            250,
            address(this),
            data,
            false,
            bytes("")
        );

        require(
            msg.value >= totalPrice + (minFee * 3) / 2,
            "You haven't paid enough."
        );

        for (uint i = 0; i < names.length; ++i) {
            IRaveMultichainExtensionOracle(prices[extensions[i].hash()])
                .getPayee()
                .call{
                value: IRaveMultichainExtensionOracle(
                    prices[extensions[i].hash()]
                ).getUSDPrice(names[i].length()) * uint256(nativePrice)
            }("");
        }

        lzEndpoint.send{value: (minFee * 3) / 2}(
            250,
            abi.encodePacked(address(this), transmitter),
            data,
            payable(msg.sender),
            address(0),
            bytes("")
        );
    }

    function setResolver(string memory name, string memory extension, address newResolver) external payable {
        // this is data we send to the reciever contract, which decodes the signer from the signature,
        // the operation to perform, and sends that information to the hub, which acts accordingly.
        bytes memory data = abi.encode(
            msg.sender,
            abi.encode(2, abi.encode(name, extension, newResolver))
        );

        (uint minFee, ) = lzEndpoint.estimateFees(
            250,
            address(this),
            data,
            false,
            bytes("")
        );

        require(
            msg.value >= (minFee * 3) / 2,
            "You haven't paid enough."
        );

        lzEndpoint.send{value: (minFee * 3) / 2}(
            250,
            abi.encodePacked(address(this), transmitter),
            data,
            payable(msg.sender),
            address(0),
            bytes("")
        );
    }

    function setResolverForSubdomain(string memory name, string memory extension, string[] memory subdomain, address newResolver) external payable {
        // this is data we send to the reciever contract, which decodes the signer from the signature,
        // the operation to perform, and sends that information to the hub, which acts accordingly.
        bytes memory data = abi.encode(
            msg.sender,
            abi.encode(3, abi.encode(name, extension, subdomain, newResolver))
        );

        (uint minFee, ) = lzEndpoint.estimateFees(
            250,
            address(this),
            data,
            false,
            bytes("")
        );

        require(
            msg.value >= (minFee * 3) / 2,
            "You haven't paid enough."
        );

        lzEndpoint.send{value: (minFee * 3) / 2}(
            250,
            abi.encodePacked(address(this), transmitter),
            data,
            payable(msg.sender),
            address(0),
            bytes("")
        );
    }

    function setPrimaryName(string memory name, string memory extension, string[] memory subdomain) external payable {
        // this is data we send to the reciever contract, which decodes the signer from the signature,
        // the operation to perform, and sends that information to the hub, which acts accordingly.
        bytes memory data = abi.encode(
            msg.sender,
            abi.encode(4, abi.encode(name, extension, subdomain))
        );

        (uint minFee, ) = lzEndpoint.estimateFees(
            250,
            address(this),
            data,
            false,
            bytes("")
        );

        require(
            msg.value >= (minFee * 3) / 2,
            "You haven't paid enough."
        );

        lzEndpoint.send{value: (minFee * 3) / 2}(
            250,
            abi.encodePacked(address(this), transmitter),
            data,
            payable(msg.sender),
            address(0),
            bytes("")
        );
    }

    function renewName(string memory name, string memory extension, uint time) external payable {
        // this is data we send to the reciever contract, which decodes the signer from the signature,
        // the operation to perform, and sends that information to the hub, which acts accordingly.
        bytes memory data = abi.encode(
            msg.sender,
            abi.encode(5, abi.encode(name, extension, time))
        );

        int nativePrice = feed.get(key);

        require(
                prices[extension.hash()] != address(0),
                string.concat(
                    "The name: ",
                    name,
                    ".",
                    extension,
                    ", does not have a price oracle on chainId ",
                    Strings.toString(chainId())
                )
            );

        uint price = IRaveMultichainExtensionOracle(prices[extension.hash()])
                    .getRenewPrice(name.length(), time) *
                uint256(nativePrice);

        (uint minFee, ) = lzEndpoint.estimateFees(
            250,
            address(this),
            data,
            false,
            bytes("")
        );

        require(
            msg.value >= price + (minFee * 3) / 2,
            "You haven't paid enough."
        );

        lzEndpoint.send{value: (minFee * 3) / 2}(
            250,
            abi.encodePacked(address(this), transmitter),
            data,
            payable(msg.sender),
            address(0),
            bytes("")
        );
    }
}
