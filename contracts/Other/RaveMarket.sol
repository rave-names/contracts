// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// saved for archival purposes

import "../Core/RaveV1/Rave.sol";

library StringManipulation {
    function _upper(bytes1 _b1) private pure returns (bytes1) {
        if (_b1 >= 0x61 && _b1 <= 0x7A) {
            return bytes1(uint8(_b1) - 32);
        }

        return _b1;
    }

    function upper(string memory _base) internal pure returns (string memory) {
        bytes memory _baseBytes = bytes(_base);
        for (uint i = 0; i < _baseBytes.length; i++) {
            _baseBytes[i] = _upper(_baseBytes[i]);
        }
        return string(_baseBytes);
    }
}

library StringsAgain {
    function compare(
        string memory _a,
        string memory _b
    ) internal pure returns (int) {
        bytes memory a = bytes(_a);
        bytes memory b = bytes(_b);
        uint minLength = a.length;
        if (b.length < minLength) minLength = b.length;
        //@todo unroll the loop into increments of 32 and do full 32 byte comparisons
        for (uint i = 0; i < minLength; i++)
            if (a[i] < b[i]) return -1;
            else if (a[i] > b[i]) return 1;
        if (a.length < b.length) return -1;
        else if (a.length > b.length) return 1;
        else return 0;
    }

    /// @dev Compares two strings and returns true iff they are equal.
    function equal(
        string memory _a,
        string memory _b
    ) internal pure returns (bool) {
        return compare(_a, _b) == 0;
    }
}

contract RaveErrors {
    struct Error {
        uint16 code;
        string message;
    }

    Error internal PASS = Error(0, "RaveErrors (0): Passed");

    Error internal NOT_AUTHORISED =
        Error(401, "RaveErrors (401): Not authorised to perform this action.");
    Error internal NOT_FOUND =
        Error(
            404,
            "RaveErrors (404): Name not found [try querying in all-capitals]"
        );
}

contract NFTMarketplace is RaveErrors {
    using StringManipulation for string;

    struct ErrorWithFallback {
        bool isError;
        Error error;
    }

    uint public sFee = 2; // 2%
    uint public initialFee = 1; // 1 FTM to sell your name
    address private treasury = 0x87f385d152944689f92Ed523e9e5E9Bd58Ea62ef;
    mapping(bytes32 => Listing) listings;
    mapping(bytes32 => Offer) offers;
    string[] allListings = [""];
    mapping(string => uint) listingIndex;
    FantomsArtNameSystem rave;

    // bytes32 is much better to use than string, so we pass a string value into this function and get a bytes32 back.
    function _makeHash(string memory input) internal pure returns (bytes32) {
        return keccak256(abi.encode(input));
    }

    function _calcFee(uint saleValue) internal view returns (uint) {
        return saleValue * (sFee / 100);
    }

    struct Listing {
        string name;
        uint value;
        uint expireTimestamp;
        bool active;
    }

    struct Offer {
        string name;
        uint value;
        uint expireTimestamp;
        bool active;
        address offeree;
    }

    event Listed(string name, uint value, uint expire);
    event Delisting(string name);

    constructor(address _rave) {
        rave = FantomsArtNameSystem(_rave);
        listings[_makeHash("")] = Listing("", 0, 0, false);
    }

    function _verifyOwnership(
        string memory name,
        address owner
    ) internal view returns (ErrorWithFallback memory) {
        // HACKERMAN (https://betterttv.com/emotes/604e7880306b602acc59cf5e)
        (bool owned, bool isOwned) = (
            rave.isOwnedByMapping(name),
            ((rave.getOwnerOfName(name) == owner) &&
                (StringsAgain.equal(rave.getNameFromOwner(owner), name)))
        );
        bool success = (owned && isOwned);
        return
            owned
                ? (
                    ErrorWithFallback(
                        !(success),
                        (success ? PASS : NOT_AUTHORISED)
                    )
                )
                : ErrorWithFallback(true, NOT_FOUND);
    }

    modifier mustPassOwnershipTest(string memory name, address sender) {
        ErrorWithFallback memory test = _verifyOwnership(name, sender);
        require(!(test.isError), test.error.message);

        _; // proceed as normal
    }

    function listName(
        string memory name,
        uint value,
        uint expireTimestamp
    ) external payable mustPassOwnershipTest(name, msg.sender) {
        // pay more if you want ig
        //require(msg.value >= initialFee, "RaveMarket: PAY THE FEE DUMBASS");
        //payable(treasury).transfer(msg.value);
        // This notation makes for better code editing, dont usually do it.
        Listing memory listing = Listing(name, value, expireTimestamp, true);

        listings[_makeHash(name)] = listing;
        listingIndex[name] = allListings.length;
        allListings.push(name);

        emit Listed(name, value, expireTimestamp);
    }

    function delistName(
        string memory name
    ) external mustPassOwnershipTest(name, msg.sender) {
        listings[_makeHash(name)] = Listing(name, 0, 0, false);

        emit Delisting(name);
    }

    function buyName(string memory name, address buyer) external payable {
        Listing memory listing = listings[_makeHash(name)];
        require(listing.active, "RaveMarket: Listing not active");
        require(
            _verifyOwnership(name, buyer).isError,
            "RaveMarket: You cannot buy your own item"
        );
        require(
            msg.value >= listing.value,
            "RaveMarket: The value sent is below the sale price"
        );
        require(
            listing.expireTimestamp > block.timestamp,
            "RaveMarket: This offer has expired"
        );

        address owner = rave.getOwnerOfName(name);

        uint fee = _calcFee(msg.value);

        (bool success, ) = treasury.call{value: fee}("");

        require(success, "RaveMarket: Paying service fee failed.");

        (bool success1, ) = owner.call{value: (msg.value - fee)}("");

        require(success1, "RaveMarket: Paying seller failed");

        delete allListings[listingIndex[name]];
        listingIndex[name] = 0;
        rave.transferName(owner, buyer, name);
    }

    function makeOffer(
        string memory name,
        uint value,
        uint expireTimestamp,
        address offeree
    ) external payable {
        require(
            msg.value == value,
            "RaveMarket: Send the amount of FTM you are offering."
        );
        require(
            value > offers[_makeHash(name)].value,
            "RaveMarket: You must offer more than what the highest offer is."
        );

        Offer memory offer = Offer(name, value, expireTimestamp, true, offeree);

        offers[_makeHash(name)] = offer;
    }

    function acceptOffer(
        string memory name
    ) external mustPassOwnershipTest(name, msg.sender) {
        Offer memory offer = offers[_makeHash(name)];

        require(
            offer.expireTimestamp > block.timestamp,
            "RaveMarket: This offer has expired"
        );

        address owner = rave.getOwnerOfName(name);

        uint fee = _calcFee(offer.value);

        (bool success, ) = treasury.call{value: fee}("");

        require(success, "RaveMarket: Paying service fee failed.");

        (bool success1, ) = owner.call{value: (offer.value - fee)}("");

        require(success1, "RaveMarket: Paying seller failed");

        if (listingIndex[name] >= 0) {
            delete allListings[listingIndex[name]];
            listingIndex[name] = 0;
        }
        delete offers[_makeHash(name)];
        rave.transferName(owner, offer.offeree, name);
    }

    function getOffer(
        string calldata name
    ) external view returns (Offer memory) {
        return offers[_makeHash(name)];
    }

    function isListed(string memory name) external view returns (bool) {
        return listings[_makeHash(name)].active || false;
    }

    function getListing(
        string memory name
    ) external view returns (Listing memory) {
        return listings[_makeHash(name)];
    }

    function getAllListings() external view returns (string[] memory) {
        return allListings;
    }

    // Fallback: reverts if Ether is sent to this smart-contract by mistake
    fallback() external {
        revert();
    }
}
