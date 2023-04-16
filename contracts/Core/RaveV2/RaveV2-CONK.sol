// SPDX-License-Identifier: Unlisence
pragma solidity >=0.8.16;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "../../Other/string.sol";
import {FantomsArtNameSystem as RaveV1} from "../RaveV1/Rave.sol";
import {RaveURIGenerator as URI} from "./RaveURIGenerator.sol";

interface wFTM is IERC20 {
    function deposit() external payable returns (uint256);
}

contract Splitter {
    address public treasury = 0x87f385d152944689f92Ed523e9e5E9Bd58Ea62ef;
    address public conkTreasury = 0xaDCB8065604A37AfEdc328877023BD0b5fb3CFda;

    modifier onlyEOA() {
        require(msg.sender == tx.origin);
        _;
    }

    receive() external payable onlyEOA {
        uint raveCut = msg.value / 6;
        conkTreasury.call{value: msg.value - raveCut}("");
        treasury.call{value: raveCut}("");
    }
}

contract RaveCONK is ERC721, ERC721Enumerable, Ownable, ERC2981 {
    using Counters for Counters.Counter;
    using strings for *;

    uint public price;
    string public extension;
    Counters.Counter private _tokenIdCounter;
    address public treasury = 0x87f385d152944689f92Ed523e9e5E9Bd58Ea62ef;
    address public conkTreasury = 0xaDCB8065604A37AfEdc328877023BD0b5fb3CFda;
    wFTM private wftm = wFTM(0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83);
    address public uri;
    address public royaltysplitter;

    mapping(bytes32 => bool) regsitered;
    mapping(uint256 => RaveName) tokenIdName;
    mapping(bytes32 => uint256) nameToTokenId;

    struct RaveName {
        string name;
        uint tokenId;
        string addresses;
        string avatar;
    }

    event Registered(string indexed name, address owner);
    event SetAddresses(string indexed name, string addresses);
    event SetAvatar(string indexed name, string avatar);
    event SetURI(address uri);
    event Migration();

    constructor(
        string memory _extension,
        uint _price,
        address _uri
    )
        ERC721(
            string.concat(string.concat("CONK .", _extension), " registry"),
            string.concat(".", _extension)
        )
    {
        price = _price;
        extension = _extension;
        uri = _uri;
        Splitter splitter = new Splitter();
        royaltysplitter = address(splitter);
    }

    // @notice Makes a keccak256 hash of a string
    // @param input string
    function _makeHash(string memory input) internal pure returns (bytes32) {
        return keccak256(abi.encode(input));
    }

    // @notice Makes a character lowercase
    // @param input char
    function __lower(bytes1 _b1) private pure returns (bytes1) {
        if (_b1 >= 0x41 && _b1 <= 0x5A) {
            return bytes1(uint8(_b1) + 32);
        }

        return _b1;
    }

    // @notice Makes a string lowercase
    // @param input string
    function _lower(string memory _base) internal pure returns (string memory) {
        bytes memory _baseBytes = bytes(_base);
        for (uint i = 0; i < _baseBytes.length; i++) {
            _baseBytes[i] = __lower(_baseBytes[i]);
        }
        return string(_baseBytes);
    }

    // @notice Register a name
    // @param name to register
    function registerName(string memory _name) public payable {
        string memory name = _lower(
            string.concat(string.concat(_name, "."), extension)
        );
        RaveCONK old = RaveCONK(0x8b09DAC87E01168b35719F7117630381D173B38C);
        require(!old.owned(_name));
        require(msg.value >= price, "Rave: You must pay the full price.");
        wftm.deposit{value: msg.value}();
        wftm.transfer(treasury, msg.value / 2);
        wftm.transfer(conkTreasury, msg.value / 2);
        bytes32 _hashedName = _makeHash(name);
        require(
            !(regsitered[_hashedName]),
            "Rave: You cant register a name thats already owned."
        );
        RaveName memory constructedName = RaveName(
            name,
            _tokenIdCounter.current(),
            "",
            ""
        );
        regsitered[_hashedName] = true;
        tokenIdName[_tokenIdCounter.current()] = constructedName;
        nameToTokenId[_hashedName] = _tokenIdCounter.current();
        _setTokenRoyalty(_tokenIdCounter.current(), royaltysplitter, 6);
        _safeMint(msg.sender, _tokenIdCounter.current());
        _tokenIdCounter.increment();
        emit Registered(name, msg.sender);
    }

    // @notice Register an array of names
    // @param names to register
    function bulkRegister(string[] memory names) external payable {
        for (uint i = 0; i < names.length; ) {
            registerName(names[i]);
            unchecked {
                i++;
            }
        }
    }

    // @notice register a name and send it to another address
    // @param name to register
    // @param address to send to
    function registerNameAndSend(
        string memory _name,
        address sendTo
    ) public payable {
        string memory name = _lower(
            string.concat(string.concat(_name, "."), extension)
        );
        RaveCONK old = RaveCONK(0x8b09DAC87E01168b35719F7117630381D173B38C);
        require(!old.owned(_name));
        require(msg.value >= price, "Rave: You must pay the full price.");
        wftm.deposit{value: msg.value}();
        wftm.transfer(treasury, msg.value / 2);
        wftm.transfer(conkTreasury, msg.value / 2);
        bytes32 _hashedName = _makeHash(name);
        require(
            !(regsitered[_hashedName]),
            string.concat(
                "Rave: You cant register a name thats already owned: ",
                name
            )
        );
        RaveName memory constructedName = RaveName(
            name,
            _tokenIdCounter.current(),
            "",
            ""
        );
        regsitered[_hashedName] = true;
        tokenIdName[_tokenIdCounter.current()] = constructedName;
        nameToTokenId[_hashedName] = _tokenIdCounter.current();
        _setTokenRoyalty(_tokenIdCounter.current(), royaltysplitter, 6);
        _safeMint(sendTo, _tokenIdCounter.current());
        _tokenIdCounter.increment();
        emit Registered(name, sendTo);
    }

    // @notice register multiple names and send to addresses
    // @param names to register
    // @param addresses to send to
    function bulkRegisterAndSend(
        string[] memory names,
        address[] memory addresses
    ) external payable {
        require(
            names.length == addresses.length,
            "Rave: The amount of addresses must be equal to the amount of names."
        );
        for (uint i = 0; i < names.length; ) {
            registerNameAndSend(names[i], addresses[i]);
            unchecked {
                i++;
            }
        }
    }

    // @notice set multichain addresses
    // @param name to edit
    // @param addresses
    function setAddresses(
        string memory _name,
        string memory addresses
    ) external {
        string memory name = _lower(_name);
        bytes32 _hashedName = _makeHash(name);
        require(
            ownerOf(nameToTokenId[_hashedName]) == msg.sender,
            "Rave: You must own the name to set the addresses."
        );
        tokenIdName[nameToTokenId[_hashedName]].addresses = addresses;
        emit SetAddresses(name, addresses);
    }

    // @notice set avatar
    // @param name to edit
    // @param avatar URL
    function setAvatar(string memory _name, string memory avatar) external {
        string memory name = _lower(_name);
        bytes32 _hashedName = _makeHash(name);
        require(
            ownerOf(nameToTokenId[_hashedName]) == msg.sender,
            "Rave: You must own the name to set the avatar."
        );
        tokenIdName[nameToTokenId[_hashedName]].avatar = avatar;
        emit SetAvatar(name, avatar);
    }

    function owned(string memory name) external view returns (bool) {
        return regsitered[_makeHash(_lower(name))];
    }

    function getAddresses(
        string memory name
    ) external view returns (string memory) {
        return tokenIdName[nameToTokenId[_makeHash(_lower(name))]].addresses;
    }

    function getAvatar(
        string memory name
    ) external view returns (string memory) {
        return tokenIdName[nameToTokenId[_makeHash(_lower(name))]].avatar;
    }

    function getOwner(string memory name) external view returns (address) {
        return ownerOf(nameToTokenId[_makeHash(_lower(name))]);
    }

    function getName(
        address owner,
        uint index
    ) external view returns (string memory) {
        return tokenIdName[tokenOfOwnerByIndex(owner, index)].name;
    }

    function setURI(address newUri) external onlyOwner {
        uri = newUri;
        emit SetURI(newUri);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, ERC721Enumerable, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function getNames(address owner) external view returns (string[] memory) {
        string[] memory names = new string[](balanceOf(owner));
        for (uint i = 0; i < balanceOf(owner); ) {
            names[i] = (tokenIdName[tokenOfOwnerByIndex(owner, i)].name);
            unchecked {
                i++;
            }
        }
        return names;
    }

    function safeTransferFrom(
        address from,
        address to,
        string memory name
    ) external {
        safeTransferFrom(from, to, nameToTokenId[_makeHash(name)]);
    }

    function transferFrom(
        address from,
        address to,
        string memory name
    ) external {
        transferFrom(from, to, nameToTokenId[_makeHash(name)]);
    }

    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        return URI(uri).generate(tokenIdName[tokenId].name);
    }

    function changeName(
        string memory name
    ) public view returns (string memory) {
        if (name.toSlice().endsWith(".FTM".toSlice())) {
            return (_lower(name).toSlice().until(".ftm".toSlice())).toString();
        } else {
            return name;
        }
    }

    function migrate(
        address ravev1,
        uint startAt,
        uint endAt
    ) external onlyOwner {
        require(
            _makeHash(extension) == _makeHash("ftm"),
            "Rave: You can only migrate .ftm names"
        );
        uint p = price;
        price = 0;
        for (uint i = startAt; i < endAt; ) {
            // @dev removes .ftm from the end of a name
            string memory name = RaveV1(ravev1).getNameFromOwner(
                RaveV1(ravev1).ownerOf(i)
            );
            name = changeName(name);
            registerNameAndSend(name, RaveV1(ravev1).ownerOf(i));
            unchecked {
                i++;
            }
        }
        price = p;
        emit Migration();
    }

    // function migrateCONK(string memory name) external {
    //     RaveCONK memory old = RaveCONK(
    //         0x8b09DAC87E01168b35719F7117630381D173B38C
    //     );
    //     require(old.getOwner(name) == msg.sender);
    //     uint p = price;
    //     price = 0;
    //     registerNameAndSend(name, msg.sender);
    //     price = p;
    //     emit Migration();
    // }

    function f(uint p) external onlyOwner {
        price = p;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal virtual override(ERC721, ERC721Enumerable) {
        ERC721Enumerable._beforeTokenTransfer(
            from,
            to,
            firstTokenId,
            batchSize
        );
    }
}
