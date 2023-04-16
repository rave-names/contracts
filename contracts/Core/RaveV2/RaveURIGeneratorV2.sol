// SPDX-License-Identifier: MIT
// Based on https://github.com/MasterSprouts/CawUsernames/blob/master/contracts/CawNameURI.sol
// Credits go to MasterSprouts
pragma solidity >=0.8.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "./RaveV2.sol";

contract RaveURIGeneratorV2 is Ownable {
    string internal description =
        "Rave Names is the first web3 username system on Fantom";
    address internal immutable rave =
        0x14Ffd1Fa75491595c6FD22De8218738525892101;

    function generate(string memory name) public view returns (string memory) {
        string[5] memory parts;
        uint8 length = uint8(bytes(name).length);

        string memory avatar = Rave(rave).getAvatar(name);
        bool shouldUseAvatar = !(uint8(bytes(avatar).length) == 0);

        uint8 fontSize = 22;
        if (length == 16) fontSize = 23;
        else if (length == 15) fontSize = 25;
        else if (length == 14) fontSize = 27;
        else if (length == 13) fontSize = 29;
        else if (length == 12) fontSize = 31;
        else if (length == 11) fontSize = 33;
        else if (length == 10) fontSize = 36;
        else if (length == 9) fontSize = 40;
        else if (length == 8) fontSize = 44;
        else if (length == 7) fontSize = 49;
        else if (length == 6) fontSize = 55;
        else if (length == 5) fontSize = 64;
        else if (length == 4)
            fontSize = 77; // xposition needs to be 89%
        else if (length == 3) fontSize = 99;
        else if (length == 2)
            fontSize = 133; // xposition needs to be 88%
        else if (length == 1) fontSize = 176;

        string memory xposition = "90";
        if (length <= 2) xposition = "88";
        else if (length <= 4) xposition = "89";

        parts[
            0
        ] = '<svg xmlns="http://www.w3.org/2000/svg" width="270" height="270" viewBox="0 0 270 270" fill="none" data-ember-extension="1"> <rect width="270" height="270" fill="url(#paint0_linear)"/> <defs> <filter id="dropShadow" color-interpolation-filters="sRGB" filterUnits="userSpaceOnUse" height="270" width="270"> <feDropShadow dx="0" dy="1" stdDeviation="2" flood-opacity="0.225" width="200%" height="200%"/> </filter> </defs>';
        parts[1] = '<text y="231" font-size="';
        parts[
            2
        ] = 'px" fill="white" filter="url(#dropShadow)" style="text-anchor: end;" x="';
        parts[3] = '%">';
        parts[4] = shouldUseAvatar
            ? string.concat(
                '</text> <defs> <style> text { font-family: monospace; font-style: normal; font-weight: bold; line-height: 34px; } svg { background-image: url("',
                avatar,
                '"); background-repeat: no-repeat; background-size: cover; } </style> </defs> </svg>'
            )
            : '</text> <defs> <style> text { font-family: monospace; font-style: normal; font-weight: bold; line-height: 34px; } </style> <linearGradient id="paint0_linear" x1="110.5" y1="140" x2="-30" gradientUnits="userSpaceOnUse" y42="37.5"> <stop stop-color="#03045e"/> <stop offset="1" stop-color="#ECc052"/> </linearGradient> <linearGradient id="paint1_linear" x1="0" y1="0" x2="269.553" y2="285.527" gradientUnits="userSpaceOnUse"> <stop stop-color="#000000"/> <stop offset="1" stop-color="#22222"/> </linearGradient> </defs> </svg>';

        string memory output = string(
            abi.encodePacked(
                parts[0],
                parts[1],
                Strings.toString(fontSize),
                parts[2],
                xposition,
                parts[3],
                name,
                parts[4]
            )
        );

        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "',
                        name,
                        '", "description": "',
                        description,
                        '", "image": "data:image/svg+xml;base64,',
                        Base64.encode(bytes(output)),
                        '"}'
                    )
                )
            )
        );
        output = string(
            abi.encodePacked("data:application/json;base64,", json)
        );

        return output;
    }

    function setDescription(string memory _description) public onlyOwner {
        description = _description;
    }
}
