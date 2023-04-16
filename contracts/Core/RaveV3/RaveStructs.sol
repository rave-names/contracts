// SPDX-License-Identifier: GPLv3

pragma solidity ^0.8.19;

struct Name {
    string name;
    address resolvee;
    bool exists;
    address resolver;
    uint256 expiry;
}
