pragma solidity >= 0.8.0;
pragma experimental ABIEncoderV2;

import "https://github.com/rave-names/contracts/blob/master/contracts/RaveV2.sol";

abstract contract RaveErrors {
  struct Error {
    uint16 code;
    string message;
  }

  struct ErrorWithFallback {
    bool isError;
    Error error;
  }

  Error internal PASS = Error(0, "RaveErrors (0): Passed");

  Error internal NOT_AUTHORISED = Error(401, "RaveErrors (401): Not authorised to perform this action.");
  Error internal NOT_FOUND = Error(404, "RaveErrors (404): Name not found [try querying in all-capitals]");
}

contract PrimaryDomainRegistrar is RaveErrors {
    mapping(address => string) primaryDomains;

    Rave internal immutable rave;

    constructor(address _rave) {
        rave = Rave(_rave);
    }

    function _verifyOwnership(
        string memory name,
        address owner
    ) internal view returns (ErrorWithFallback memory) {
        // HACKERMAN (https://betterttv.com/emotes/604e7880306b602acc59cf5e)
        (bool owned, bool isOwned) = (rave.owned(name), (rave.getOwner(name) == owner));
        bool success = (owned && isOwned);
        return owned ? (ErrorWithFallback(!(success), (success ? PASS : NOT_AUTHORISED))) : ErrorWithFallback(true, NOT_FOUND);
    }

    modifier mustPassOwnershipTest(
        string memory name,
        address sender
    ) {
        ErrorWithFallback memory test = _verifyOwnership(name, sender);
        require(!(test.isError), test.error.message);

        _; // proceed as normal
    }

    function getPrimaryDomain(
        address owner
    ) external view returns(string memory) {
        string memory impliedName = primaryDomains[owner];
        if (_verifyOwnership(impliedName, owner).error.code == 0) {
            return impliedName;
        } else {
            return "";
        }
    }

    function setPrimaryDomain(
        string memory name
    ) external payable mustPassOwnershipTest(name, msg.sender) {
        primaryDomains[msg.sender] = name;
    }
}
