// SPDX-Lisence-Identifier: Unlisenced
pragma solidity ^0.8.19;

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract RaveProxy is TransparentUpgradeableProxy {
    constructor(
        address implementation,
        address admin,
        bytes memory data
    ) payable TransparentUpgradeableProxy(implementation, admin, data) {}
}

contract RaveAdmin is ProxyAdmin {
    constructor() ProxyAdmin() {}
}
