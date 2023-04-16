// SPDX-License-Identifier: GPLv3

pragma solidity ^0.8.19;
/*
 * Rave v3
 *
 * A multi-chain name service, powered by layer zero. The storage for the names and
 * all their data is done on Fantom, due to the low costs. Users can register .rave
 * names in either >=100 RAVE or the equivalent in the chain's native token. The
 * plus-side to multichain names is that anyone can resolve a name on any chain,
 * natively. This allows for developers to use .rave names in the stead of addresses
 * as a sort of verification, or anti-bot measure.
 *
 * Rave v3 will be compatiable with any ENS-enabled wallet through ENS sub-domains
 * (similar to the current .ftm.fyi solution), just with an on-chain resolver as a
 * pose to an off-chain one.
 *
 * This contract is designed to store the resolver values, and is intended to be deployed
 * on the Fantom chain. We call it the 'Hub'.
 */

import {IRaveV3Resolver} from "./IRaveV3Resolver.sol";
import {IRavePriceFeed} from "./IRavePriceFeed.sol";
import {StringUtils} from "../../Other/StringUtilities.sol";
import {Name} from "./RaveStructs.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * To-do list:
 *  - validate name ownership (untested)
 *  - validate subdomain ownership (untested)
 *  - resolve name (untested)
 *  - resolve subdomain (untested)
 *  - resolve record (untested)
 *  - set resolver for a name in a tld (untested)
 *  - set record for a name in a tld (untested)
 *  - 2 above for subdomains (2/2) (untested)
 *  - renew a name (untested)
 *  - renew subdomain (untested)
 *  - set resolver for a tld (not needed, if they want to change the resolver make it upgradeable)
 *  - reset an extension [onlyOwner] (untested)
 *  - set payee for a tld (untested)
 *  - primary domain (untested)
 *  - reverse lookup (untested)
 *  - get owned (untested)
 */

contract OmniRaveStorage is OwnableUpgradeable, UUPSUpgradeable {
    IRavePriceFeed public feed;
    address lzReciever;

    mapping(bytes32 extension => Extension data) public extensions;
    mapping(address user => ReverseRecord record) public reverseRecords;

    using StringUtils for string;

    struct Extension {
        address resolver;
        bool valid;
        address payee;
    }

    struct ReverseRecord {
        bool isSubdomain;
        string name;
        string extension;
        string[] subdomain;
    }

    struct KeyValue {
        string key;
        string value;
    }

    function initialize(
        address priceFeed,
        address _lzReciever
    ) external initializer {
        feed = IRavePriceFeed(priceFeed);
        lzReciever = _lzReciever;
        __Ownable_init_unchained();
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    modifier onlyLZReciever() {
        require(msg.sender == lzReciever);

        _;
    }

    modifier onlyOwnerOfName(
        string memory nme,
        string memory ext,
        address probe
    ) {
        address owner = IRaveV3Resolver(extensions[ext.hash()].resolver)
            .getController(nme.hash());

        require(probe == owner);

        _;
    }

    modifier onlyOwnerOfSubdomain(
        string[] memory subdomains,
        string memory name,
        string memory extension,
        address probe
    ) {
        address owner = _resolver(extension, name, subdomains, 1).getController(
            subdomains[subdomains.length - 1].hash()
        );

        require(owner == probe);

        _;
    }

    function _resolver(
        string memory extension,
        string memory name,
        string[] memory subdomain,
        uint offset
    ) internal view returns (IRaveV3Resolver resolver) {
        IRaveV3Resolver extensionResolver = IRaveV3Resolver(
            extensions[extension.hash()].resolver
        );
        resolver = IRaveV3Resolver(
            extensionResolver.resolveName(name.hash()).resolver
        );

        for (uint64 i = 1; i < subdomain.length - offset; ++i) {
            resolver = IRaveV3Resolver(
                resolver.resolveName(subdomain[i].hash()).resolver
            );
        }
    }

    /*********************\
    |    LZ Functions      |
    \*********************/

    function setReciever(address _new) external onlyOwner {
        lzReciever = _new;
    }

    function recieve(
        uint16 opCode,
        bytes memory data,
        address sender
    ) external onlyLZReciever {
        // Register Name
        if (opCode == 1) {
            (
                string[] memory names,
                string[] memory _extensions,
                address[] memory resolvers,
                address[] memory to
            ) = abi.decode(data, (string[], string[], address[], address[]));
            uint totalPrice = 0;
            for (uint i = 0; i < names.length; ) {
                totalPrice += IRaveV3Resolver(
                    extensions[_extensions[i].hash()].resolver
                ).getUSDPrice(names[i].length());
                unchecked {
                    ++i;
                }
            }
            for (uint i = 0; i < names.length; ) {
                require(
                    !names[i].contains(" ") &&
                        !names[i].contains(".") &&
                        !_extensions[i].contains(" ") &&
                        !_extensions[i].contains(".")
                );
                IRaveV3Resolver(extensions[_extensions[i].hash()].resolver)
                    .registerName(names[i], to[i], resolvers[i]);
                unchecked {
                    ++i;
                }
            }
        }

        // Set Resolver For Name
        if (opCode == 2) {
            (
                string memory name,
                string memory extension,
                address newResolver
            ) = abi.decode(data, (string, string, address));
            address owner = IRaveV3Resolver(
                extensions[extension.hash()].resolver
            ).getController(name.hash());

            require(sender == owner);
            bytes32 ext = extension.hash();
            bytes32 nme = name.hash();

            IRaveV3Resolver resolver = IRaveV3Resolver(
                extensions[ext].resolver
            );

            resolver.setResolver(nme, newResolver);
        }

        // Set resolver for subdomain
        if (opCode == 3) {
            (
                string memory name,
                string memory extension,
                string[] memory subdomain,
                address newResolver
            ) = abi.decode(data, (string, string, string[], address));

            _resolver(extension, name, subdomain, 1).setResolver(
                subdomain[subdomain.length - 1].hash(),
                newResolver
            );
        }

        if (opCode == 4) {
            (
                string memory name,
                string memory extension,
                string[] memory subdomain
            ) = abi.decode(data, (string, string, string[]));
            reverseRecords[sender] = ReverseRecord({
                isSubdomain: (subdomain.length > 0),
                name: name,
                extension: extension,
                subdomain: subdomain
            });
        }

        if (opCode == 5) {
            (
                string memory name,
                string memory extension,
                string[] memory subdomain,
                uint time
            ) = abi.decode(data, (string, string, string[], uint));

            IRaveV3Resolver resolver = _resolver(extension, name, subdomain, 1);

            resolver.renew(name.hash(), time);
        }
    }

    /*********************\
    |    View Functions    |
    \*********************/

    function getUSDPriceOfExtension(
        string memory extension
    ) internal pure returns (uint256) {
        uint length = extension.length();

        if (length == 1) {
            return 25000;
        }
        if (length == 2) {
            return 7500;
        }
        if (length == 3) {
            return 3000;
        }
        if (length == 4) {
            return 1000;
        }
        return 500;
    }

    function getUSDPriceOfName(
        string memory extension,
        string memory name
    ) internal view returns (uint256 price) {
        IRaveV3Resolver resolver = IRaveV3Resolver(
            extensions[extension.hash()].resolver
        );

        uint length = name.length();

        price = resolver.getUSDPrice(length);
    }

    function getUSDPriceOfSubdomain(
        string[] memory subdomain,
        string memory extension,
        string memory name
    ) internal view returns (uint256 price) {
        return
            _resolver(extension, name, subdomain, 1).getUSDPrice(
                subdomain[subdomain.length - 1].length()
            );
    }

    function resolveName(
        string memory name,
        string memory extension,
        string[] memory subdomains
    ) external view returns (Name memory) {
        return
            _resolver(extension, name, subdomains, 1).resolveName(
                subdomains[subdomains.length - 1].hash()
            );
    }

    function resolveRecord(
        string memory key,
        string memory name,
        string memory extension,
        string[] memory subdomains
    ) external view returns (string memory) {
        return
            _resolver(extension, name, subdomains, 1).getRecord(
                subdomains[subdomains.length - 1].hash(),
                key.hash()
            );
    }

    function _reverseLookupSubdomain(
        address owner,
        ReverseRecord memory record
    )
        internal
        view
        onlyOwnerOfSubdomain(
            record.subdomain,
            record.name,
            record.extension,
            owner
        )
        returns (string memory name)
    {
        for (uint i = 0; i < record.subdomain.length; ++i) {
            name = string.concat(name, ".", record.subdomain[i]);
        }
        name = string.concat(name, ".", record.name, ".", record.extension);
    }

    function reverseLookup(
        address owner
    ) external view returns (string memory) {
        ReverseRecord memory record = reverseRecords[owner];
        return _reverseLookupSubdomain(owner, record);
    }

    function isOwned(
        string memory name,
        string memory extension
    ) external view returns (bool) {
        return
            IRaveV3Resolver(extensions[extension.hash()].resolver).getOwned(
                name.hash()
            );
    }

    /**********************\
    |    Write Functions    |
    \**********************/

    function setFeed(address _new) external onlyOwner {
        feed = IRavePriceFeed(_new);
    }

    function withdraw() external onlyOwner returns (bool success) {
        (success, ) = address(0x87f385d152944689f92Ed523e9e5E9Bd58Ea62ef).call{
            value: address(this).balance
        }("");
    }

    function createRegistrar(
        address resolver,
        string memory extension,
        address payee
    ) external payable {
        require(extension.hash() != string("rave").hash());
        int ftmPrice = feed.get(string("FTMUSD").hash());

        uint ftmToPay = uint(ftmPrice) * getUSDPriceOfExtension(extension);

        require(msg.value >= ftmToPay);

        (bool success, ) = msg.sender.call{value: msg.value - ftmToPay}("");

        require(success);

        extensions[extension.hash()] = Extension({
            resolver: resolver,
            valid: true,
            payee: payee
        });
    }

    // TODO: Optimise this.

    function register(
        string[] memory names,
        string[] memory _extensions,
        address[] memory resolvers,
        address[] memory to
    ) external payable {
        int ftmPrice = feed.get(string("FTMUSD").hash());

        uint totalPrice = 0;

        for (uint i = 0; i < names.length; ) {
            require(
                !names[i].contains(" ") &&
                    !names[i].contains(".") &&
                    !_extensions[i].contains(" ") &&
                    !_extensions[i].contains(".")
            );

            uint ftmToPay = uint(ftmPrice) *
                getUSDPriceOfName(_extensions[i], names[i]);
            totalPrice += ftmToPay;
            unchecked {
                ++i;
            }
        }

        require(msg.value >= totalPrice);

        for (uint i = 0; i < names.length; ) {
            (bool success, ) = extensions[_extensions[i].hash()].payee.call{
                value: uint(ftmPrice) *
                    getUSDPriceOfName(_extensions[i], names[i])
            }("");
            require(success);
            IRaveV3Resolver(extensions[_extensions[i].hash()].resolver)
                .registerName(names[i], to[i], resolvers[i]);
            unchecked {
                ++i;
            }
        }
    }

    function registerSubdomiain(
        string[][] memory subdomains,
        string[] memory names,
        string[] memory _extensions,
        address[] memory resolvers,
        address[] memory to
    ) external payable {
        int ftmPrice = feed.get(string("FTMUSD").hash());

        uint totalPrice = 0;

        for (uint i = 0; i < names.length; ) {
            require(
                !names[i].contains(" ") &&
                    !names[i].contains(".") &&
                    !_extensions[i].contains(" ") &&
                    !_extensions[i].contains(".")
            );

            uint ftmToPay = uint(ftmPrice) *
                getUSDPriceOfSubdomain(subdomains[i], _extensions[i], names[i]);
            totalPrice += ftmToPay;
            unchecked {
                ++i;
            }
        }

        require(msg.value >= totalPrice);

        for (uint i = 0; i < names.length; ) {
            (bool success, ) = _resolver(
                _extensions[i],
                names[i],
                subdomains[i],
                1
            ).owner().call{
                value: uint(ftmPrice) *
                    getUSDPriceOfSubdomain(
                        subdomains[i],
                        _extensions[i],
                        names[i]
                    )
            }("");
            require(success);
            _resolver(_extensions[i], names[i], subdomains[i], 1).registerName(
                subdomains[i][subdomains[i].length - 1],
                to[i],
                resolvers[i]
            );
            unchecked {
                ++i;
            }
        }
    }

    function setResolver(
        string memory name,
        string memory extension,
        address newResolver
    ) external onlyOwnerOfName(name, extension, msg.sender) {
        bytes32 ext = extension.hash();
        bytes32 nme = name.hash();

        IRaveV3Resolver resolver = IRaveV3Resolver(extensions[ext].resolver);

        resolver.setResolver(nme, newResolver);
    }

    function setResolverForSubdomain(
        string memory name,
        string memory extension,
        string[] memory subdomain,
        address newResolver
    ) external onlyOwnerOfSubdomain(subdomain, name, extension, msg.sender) {
        _resolver(extension, name, subdomain, 1).setResolver(
            subdomain[subdomain.length - 1].hash(),
            newResolver
        );
    }

    function resetExtension(string memory extension) external onlyOwner {
        extensions[extension.hash()] = Extension(address(0), false, address(0));
    }

    function setPayee(string memory extension, address payee) external {
        IRaveV3Resolver resolver = IRaveV3Resolver(
            extensions[extension.hash()].resolver
        );

        require(msg.sender == resolver.owner());

        extensions[extension.hash()].payee = payee;
    }

    function renewName(
        string memory name,
        string memory extension,
        string[] memory subdomain,
        uint time
    )
        external
        payable
        onlyOwnerOfSubdomain(subdomain, name, extension, msg.sender)
    {
        IRaveV3Resolver resolver = _resolver(extension, name, subdomain, 1);

        string memory s = subdomain[subdomain.length - 1];

        if (resolver.getRenewPrice(s.length(), time) > 0) {
            uint price = uint(feed.get(string("FTMUSD").hash())) *
                resolver.getRenewPrice(s.length(), time);
            require(msg.value >= price);
            (bool success, ) = msg.sender.call{value: msg.value - price}("");
            require(success);
        }

        resolver.renew(s.hash(), time);
    }

    function setRecord(
        string memory name,
        string memory extension,
        KeyValue memory keyvalue
    ) external onlyOwnerOfName(name, extension, msg.sender) {
        bytes32 ext = extension.hash();
        bytes32 nme = name.hash();

        IRaveV3Resolver resolver = IRaveV3Resolver(extensions[ext].resolver);

        resolver.setRecord(nme, keyvalue.key.hash(), keyvalue.value);
    }

    function setRecordForSubdomain(
        string memory name,
        string memory extension,
        string[] memory subdomain,
        KeyValue memory keyvalue
    ) external onlyOwnerOfSubdomain(subdomain, name, extension, msg.sender) {
        _resolver(extension, name, subdomain, 1).setRecord(
            subdomain[subdomain.length - 1].hash(),
            keyvalue.key.hash(),
            keyvalue.value
        );
    }

    function setPrimaryName(
        string memory name,
        string memory extension,
        string[] memory subdomain
    ) external onlyOwnerOfSubdomain(subdomain, name, extension, msg.sender) {
        reverseRecords[msg.sender] = ReverseRecord({
            isSubdomain: (subdomain.length > 0),
            name: name,
            extension: extension,
            subdomain: subdomain
        });
    }
}
