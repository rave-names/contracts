pragma solidity >=0.8.18;

// SPDX-License-Identifier: Unlisence

library NumberUtils {
    function toDecimals(
        uint input,
        uint decimals
    ) internal pure returns (uint) {
        return (input * (10 ** decimals));
    }

    function clamp(uint self, uint min, uint max) internal pure returns (uint) {
        return (self < min) ? min : (self > max) ? max : self;
    }
}
