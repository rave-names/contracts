// SPDX-License-Identifier: GPLv3

pragma solidity ^0.8.19;

contract SignatureVerifier {
    function splitSignature(
        bytes memory signature
    ) public pure returns (uint8 v, bytes32 r, bytes32 s) {
        require(signature.length == 65, "length != 65");

        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }
    }

    function recoverSigner(
        bytes32 message,
        bytes memory signature
    ) public pure returns (address) {
        (uint8 v, bytes32 r, bytes32 s) = splitSignature(signature);
        return ecrecover(message, v, r, s);
    }
}
