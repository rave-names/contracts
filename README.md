# Rave Contracts

⚠️ These docs are a WIP! ⚠️

## Rave Tribus
#### A.K.A. Rave V3

### Name and TLD hashing
Strings are expensive to store, so instead, we use `bytes32`. This is the algorithm to get a name or extension's hash is the following (using ethers v6):
```ts
function hash(name: string): string {
    return ethers.keccak256(ethers.AbiCoder.encode(["string"],[name]));
}
```

### Retrieving mapping values
All the Rave V3 mappings are public so you can use regular function calls. An example of how this would be done in ethers v6 is:
```ts
function getExtensionDetails(extension: string) {
    return OmniRaveStorage.extensions(hash(extesnion));
}
```
Or in solidity:
```sol
contract Foo {
    OmniRaveStorage hub;

    // @param extension hashed extension
    function extensionData(bytes32 extension) public view returns (address resolver, bool valid, address payee) {
        (resolver, valid, payee) = hub.extensions(extension);
    }
}
```
Pretty straight-forward.

### Deploying your own TLD
Rave V3 allows for custom registrars, as long as you implement [IRaveV3Resolver](/contracts/Core/RaveV3/IRaveV3Resolver.sol). An example of how this can be done is [here](/contracts/Core/RaveV3/RaveV3BasicRegistrar.sol). A resolver should implement the resolution and registration logic itself, and write functions should be only callable by the `OmniRaveStorage` contract, excluding ERC721 functions. A RaveV3 resolver should also implement an `owner()` function for management of a TLD.<br /><br />
You also need to deploy a [Multichain Oracle](/contracts/Core/RaveV3/RaveV3BasicMultichainOracle.sol), which isn't an oracle in the traditional sense of the word, but should implement the same logic your Resolver does for pricing of domain names. It should implement [IRaveMultichainExtensionOracle](/contracts/Core/RaveV3/IRaveMultichainExtensionOracle.sol), which requires a `getPayee()` method. This just tells the handlers on non-home chains where to send registration fees.<br /><br />
To start resolution of names by your resolver, you need to call `createRegistrar(address resolver, string extension, address payee)`, where `resolver` is your deployed resolver's address, `extension` is your target TLD extension and `payee` is the address that recieves payment for the registrations. The cost for this is the following:
 - 1 character (.a, .x, .z) => $25,000 USD
 - 2 characters (.ab, .oo, .xx) => $7,500 USD
 - 3 characters (.abc, .hey, .ppp) => $3,000 USD
 - 4 characters (.wwww, .rave, .lmao) => $1,000 USD
 - 5+ characters (.hello, .verylongtld, .mydao) => $500 USD
(All prices must be paid in native FTM)

### Price feeds
RaveV3 uses Chainlink price feeds to price all registrations, though we use a proxy contract ([RavePriceFeed](/contracts/Core/RaveV3/RavePriceFeed.sol)) to retrieve this information, which can implement custom logic.