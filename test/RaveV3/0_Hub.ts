const { expect } = require("chai");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

describe("Rave Hub", () => {
    const deployHubFixture = async () => {
        const [deployer] = await ethers.getSigners();

        const Hub = await ethers.getContractFactory("OmniRaveStorage");
        const hub = await Hub.deploy();

        await hub.deployed();
        await hub.initialize(ethers.constants.AddressZero);

        return { Hub, hub, deployer: deployer.address };
    };

    it(`Deployer should be the owner`, async () => {
        const { hub, deployer } = await loadFixture(deployHubFixture);

        const owner = await hub.owner();
        expect(owner).to.equal(deployer);
    });

    it(`Test split into subdomains`, async () => {
        const { hub, deployer } = await loadFixture(deployHubFixture);

        await hub["resolveName(string)"]("hello.ftm.x");
    })
});