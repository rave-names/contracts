// SPDX-License-Identifier: GPLv3

pragma solidity ^0.8.19;

/*
 * A contract that resolves Rave Names with basic funcitonality. Allows for DNS-like
 * records to be set. Registrations, etc are controlled by the Rave Hub.
 *
 * Subdomain resolution is done with another resolver, and can be used to create
 * subdomains of subdomains, i.e.
 *  hello.my.name.is.z.ftm, in which is.z.ftm, name.is.z.ftm are all different names.
 */

import {IRaveV3Resolver} from "./IRaveV3Resolver.sol";
import {OmniRaveStorage as RaveV3} from "./RaveV3.sol";
import {Name} from "./RaveStructs.sol";
import {StringUtils} from "../../Other/StringUtilities.sol";
import {ERC721EnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "hardhat/console.sol";

contract RaveV3BasicRegistry is
    UUPSUpgradeable,
    IRaveV3Resolver,
    ERC721EnumerableUpgradeable,
    OwnableUpgradeable
{
    mapping(bytes32 name => Name data) public names;
    mapping(bytes32 name => mapping(bytes32 key => string record))
        public records;
    address hub;
    uint price = 5;

    uint256 gracePeriod = 30 days;

    using StringUtils for string;

    function initialize(
        address _hub,
        string calldata a,
        string calldata b
    ) external initializer {
        hub = _hub;
        __ERC721_init(a, b);
        __Ownable_init();
        __UUPSUpgradeable_init();
    }

    /*********************\
    |    Access Control    |
    \*********************/

    modifier onlyHub() {
        require(msg.sender == hub, "onlyHub: Not hub.");

        _;
    }

    modifier existCheck(bytes32 name, bool check) {
        // prevent underflow for numbers non-registered names (in which the expiry value is 0, so 0 - block.timestamp is negative and will result in a 0x11)
        if (names[name].exists) {
            bool exists = ((names[name].expiry - block.timestamp) <
                (52 weeks + gracePeriod));
            require(
                check ? !exists : exists,
                check
                    ? "RaveV3Registrar: This name exists."
                    : "RaveV3Registrar: This name does not exist."
            );
        }
        _;
    }

    /**********************\
    |    Write Functions    |
    \**********************/

    function registerName(
        string calldata _name,
        address _owner,
        address resolvee
    ) external onlyHub existCheck(_name.hash(), true) {
        Name memory name = Name({
            name: _name,
            resolvee: resolvee,
            exists: true,
            resolver: address(0),
            expiry: block.timestamp + 52 weeks
        });

        names[_name.hash()] = name;

        _mint(_owner, _name.nameHash());
    }

    function setResolver(bytes32 name, address resolver) external onlyHub {
        names[name].resolver = resolver;
    }

    function setRecord(
        bytes32 name,
        bytes32 key,
        string calldata value
    ) external onlyHub {
        records[name][key] = value;
    }

    function setPrice(uint _price) external onlyOwner {
        price = _price;
    }

    function renew(bytes32 name, uint time) external onlyHub {
        names[name].expiry = block.timestamp + time;
    }

    /**********************\
    |    View Functions     |
    \**********************/

    function resolveName(
        bytes32 name
    ) external view existCheck(name, false) returns (Name memory) {
        return names[name];
    }

    function getUSDPrice(uint) external view returns (uint) {
        return price;
    }

    function getRenewPrice(uint, uint) external pure returns (uint) {
        return 0;
    }

    function resolveSubDomain(
        bytes32 name,
        bytes32 subdomain
    ) external view existCheck(name, false) returns (Name memory, address) {
        require(
            names[name].resolver != address(0),
            "RaveV3Registrar: There is no resolver associated with this name."
        );

        Name memory resolvedName = IRaveV3Resolver(names[name].resolver)
            .resolveName(subdomain);
        address _owner = IRaveV3Resolver(names[name].resolver).getController(
            subdomain
        );

        return (resolvedName, _owner);
    }

    function getRecord(
        bytes32 name,
        bytes32 key
    ) external view existCheck(name, false) returns (string memory) {
        return records[name][key];
    }

    function getController(
        bytes32 name
    ) external view existCheck(name, false) returns (address) {
        return ownerOf(uint(name));
    }

    function getOwned(bytes32 name) external view returns (bool) {
        return names[name].exists;
    }

    // TODO: Add a beforeTokenTransfer that changes the resolvee when a token is transferred (maybe ?)

    // overrides
    function _authorizeUpgrade(address) internal override onlyOwner {}

    function owner()
        public
        view
        virtual
        override(OwnableUpgradeable, IRaveV3Resolver)
        returns (address)
    {
        return super.owner();
    }
}
