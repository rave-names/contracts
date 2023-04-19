// SPDX-License-Identifier: GPLv3
pragma solidity ^0.8.19;
pragma abicoder v2;

import {NonblockingLzAppUpgradeable as NBLA} from "@layerzerolabs/solidity-examples/contracts/contracts-upgradable/lzApp/NonblockingLzAppUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {StringUtils} from "../../Other/StringUtilities.sol";
import {IRaveV3Resolver} from "./IRaveV3Resolver.sol";
import {OmniRaveStorage} from "./RaveV3.sol";

contract RaveLZTransmitter is NBLA, UUPSUpgradeable {
    OmniRaveStorage hub;

    mapping(uint16 => address) multichainHandler;

    function initialize(
        address endpoint,
        address _hub
    ) external onlyInitializing {
        __NonblockingLzAppUpgradeable_init(endpoint);
        hub = OmniRaveStorage(_hub);
    }

    using StringUtils for string;

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function decodeData(
        bytes memory data
    )
        internal
        pure
        returns (
            address signer,
            bytes memory arguments
        )
    {
        (signer, arguments) = abi.decode(
            data,
            (address, bytes)
        );
    }

    function setHandler(uint16 chainId, address handler) external onlyOwner {
        multichainHandler[chainId] = handler;
    }

    function _nonblockingLzReceive(
        uint16 chainId,
        bytes memory srcAddress,
        uint64 nonce,
        bytes memory payload
    ) internal override {
        require(msg.sender == address(lzEndpoint), "msg.sender != endpoint.");

        (address signer, bytes memory data) = decodeData(
            payload
        );

        // encodePacked turns message into bytes from bytes32
        (uint16 opCode, bytes memory callData) = abi.decode(
            data,
            (uint16, bytes)
        );

        hub.recieve(opCode, callData, signer);
    }

    function registerExtensionOnChain(
        uint16 chainId,
        string memory extension,
        address oracle
    ) external payable {
        (address resolver, , ) = hub.extensions(extension.hash());
        require(IRaveV3Resolver(resolver).owner() == msg.sender);

        bytes memory data = abi.encode(extension.hash(), oracle);

        (uint minFee, ) = lzEndpoint.estimateFees(
            chainId,
            address(this),
            data,
            false,
            bytes("")
        );

        require(
            msg.value >= minFee,
            "You must pay more for the multichain transfer fee"
        );

        lzEndpoint.send{value: msg.value}(
            chainId,
            abi.encodePacked(address(this), multichainHandler[chainId]),
            data,
            payable(msg.sender),
            address(0),
            bytes("")
        );
    }
}
