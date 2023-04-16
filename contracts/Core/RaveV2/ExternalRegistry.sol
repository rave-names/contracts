pragma solidity >=0.8.0;
pragma experimental ABIEncoderV2;
//SPDX-License-Identifier: UNLICENSED

import {StringUtils as Strings} from "../../Other/Strings.sol";

interface IRaveBase {
    function getNameFromOwner(
        address owner
    ) external view returns (string memory);

    function isOwnedByMapping(string memory name) external view returns (bool);

    function getOwnerOfName(string memory name) external view returns (address);
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

contract externalRegistry is RaveErrors {
    string public constant RAVE_IDENTIFIER =
        "0x61313633366464613333613232353239646166633138323164323562303966326565356264613761663736646164613633656636323336613134643730656362";
    // SHA-256 hash of 'externalRegistry[RaveExtenders]' in hex format

    event SetText(string name, string key, string value);

    struct ErrorWithFallback {
        bool isError;
        Error error;
    }

    IRaveBase public rave;

    constructor(address _rave) {
        rave = IRaveBase(_rave);
    }

    // bytes32 is much better to use than string, so we pass a string value into this function and get a bytes32 back.
    function _makeHash(string memory input) internal pure returns (bytes32) {
        return keccak256(abi.encode(input));
    }

    //      \/ NAME =======>  \/ KEY  => \/ VALUE        //
    mapping(string => mapping(bytes32 => string)) registry;

    mapping(string => string[]) addedRecords;

    function _setRegistryValue(
        string memory name,
        bytes32 key,
        string memory value
    ) internal {
        registry[name][key] = value;
    }

    function _getRegistryValue(
        string memory name,
        bytes32 key
    ) internal view returns (string memory) {
        return registry[name][key];
    }

    function _getRecords(
        string memory name
    ) internal view returns (string[] memory) {
        return addedRecords[name];
    }

    function _verifyOwnership(
        string memory name,
        address owner
    ) internal view returns (ErrorWithFallback memory) {
        // HACKERMAN (https://betterttv.com/emotes/604e7880306b602acc59cf5e)
        (bool owned, bool isOwned) = (
            rave.isOwnedByMapping(name),
            ((rave.getOwnerOfName(name) == owner) &&
                (Strings.equal(rave.getNameFromOwner(owner), name)))
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

    function setText(
        string memory name,
        string memory key,
        string memory value
    ) external mustPassOwnershipTest(name, msg.sender) {
        bytes32 _key = _makeHash(key);
        _setRegistryValue(name, _key, value);
        addedRecords[name].push(key);
        emit SetText(name, key, value);
    }

    function getText(
        string memory name,
        string memory key
    ) external view returns (string memory) {
        return _getRegistryValue(name, _makeHash(key));
    }

    function getRecords(
        string memory name
    ) external view returns (string[] memory) {
        return _getRecords(name);
    }
}
