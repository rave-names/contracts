const { expect } = require("chai");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const keccak256 = require("keccak256");

const abi = ethers.utils.defaultAbiCoder;


describe("Rave Basic Registrar", () => {
    const deployRegistryFixture = async () => {
        const [deployer] = await ethers.getSigners();

        const Hub = await ethers.getContractFactory("OmniRaveStorage");
        const hub = await Hub.deploy();

        const Registry = await ethers.getContractFactory("RaveV3BasicRegistry");
        const registry = await Registry.deploy(); 

        await hub.deployed();
        await registry.deployed();
        await hub.initialize(ethers.constants.AddressZero, ethers.constants.AddressZero);
        await registry.initialize(deployer.address, "Rave Names .ftm", ".ftm");

        return { Hub, hub, Registry, registry, deployer: deployer.address };
    };

    it("ERC721 Names should be set correctly", async () => {
        const { registry } = await loadFixture(deployRegistryFixture);

        const name = await registry.name();
        const symbol = await registry.symbol();

        expect(name).to.equal("Rave Names .ftm");
        expect(symbol).to.equal(".ftm");
    });

    it("Register name and resolve correctly via registrar", async () => {
        const { registry, hub, deployer } = await loadFixture(deployRegistryFixture);

        await registry.registerName("z", deployer, deployer);

        const resolved = await registry.resolveName(keccak256(abi.encode(
            ["string"],
            ["z"]
        )));

        expect(resolved.name).to.equal("z");
        expect(resolved.resolvee).to.equal(deployer);
        expect(resolved.exists).to.equal(true);
        expect(resolved.resolver).to.equal(ethers.constants.AddressZero);
    });

    
});