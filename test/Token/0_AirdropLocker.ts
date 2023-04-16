import { expect } from "chai";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { time } from "@nomicfoundation/hardhat-network-helpers";
import { ethers, waffle } from "hardhat";
import { MerkleTree } from "merkletreejs";
import keccak256 from "keccak256"; 

const YEAR = 604800 * 52;
// const provider = waffle.provider;

describe("Airdrop Locker", () => {
    const deployLockerFixture = async () => {
        const [deployer] = await ethers.getSigners();

        const Handler = await ethers.getContractFactory("AirdropHandler");
        const handler = await Handler.deploy();
        const MockERC20 = await ethers.getContractFactory("MockERC20");
        const erc20 = await MockERC20.deploy(100000000000000000000000000000n, handler.address);

        const users = [    
            { address: deployer.address, amount: 100000000 },    
        ]; 

        const elements = users.map((x) =>     
            ethers.utils.solidityKeccak256(
                ["address", "uint256"], [x.address, x.amount]));

        const tree = new MerkleTree(elements, keccak256, { sort: true });
        // Generate the root 
        const root = tree.getHexRoot();

        await handler.deployed();
        await erc20.deployed();
        await handler.initialize(erc20.address, root);

        return { Handler, handler, RAVE: MockERC20, rave: erc20, tree, users, elements, deployer: deployer.address };
    }

    it("Should start lock and return correct values", async () => {
        const { deployer, handler, tree, elements } = await loadFixture(deployLockerFixture);

        await handler.startLock(100000000, tree.getHexProof(elements[0]), { value: ethers.utils.parseEther("10") });

        const lockData = await handler.lock(deployer);

        const lock = lockData[0];
        const claimed = lockData[1];

        expect(lock.active).to.equal(true);
        expect(lock.ftmClaimed).to.equal(false);
        expect(lock.unlockTime).to.equal(1676293200 + YEAR * 4);
        expect(lock.ftmUnlockTime).to.equal(await time.latest() + 10518972);
        expect(lock.amount).to.equal(ethers.BigNumber.from(200000));
        expect(claimed).to.equal(true);
    });

    it("Should not be able to claim FTM immediately", async () => {
        const { deployer, handler, tree, elements } = await loadFixture(deployLockerFixture);

        await handler.startLock(100000000, tree.getHexProof(elements[0]), { value: ethers.utils.parseEther("10") });

        await expect(handler.claimFTM()).to.be.revertedWith("You cannot claim your FTM yet.");
    });

    it("Should not be able to claim RAVE immediately", async () => {
        const { deployer, handler, tree, elements } = await loadFixture(deployLockerFixture);

        await handler.startLock(100000000, tree.getHexProof(elements[0]), { value: ethers.utils.parseEther("10") });

        await expect(handler.claimRAVE()).to.be.revertedWith("You cannot claim your RAVE yet.");
    });

    it("Should be able to claim FTM after 2 years", async () => {
        const { deployer, handler, tree, elements } = await loadFixture(deployLockerFixture);

        const intitialBalance = await ethers.provider.getBalance(deployer);

        await handler.startLock(100000000, tree.getHexProof(elements[0]), { value: ethers.utils.parseEther("10") });

        await time.increase(YEAR * 2);

        await handler.claimFTM();

        const afterBalance = await ethers.provider.getBalance(deployer);

        // allow for gas
        expect(afterBalance).to.be.approximately(intitialBalance, 15000000000000000000n);
    });

    it("Should be able to claim FTM after more than 2 years", async () => {
        const { deployer, handler, tree, elements } = await loadFixture(deployLockerFixture);

        const intitialBalance = await ethers.provider.getBalance(deployer);

        await handler.startLock(100000000, tree.getHexProof(elements[0]), { value: ethers.utils.parseEther("10") });

        await time.increase(YEAR * 2.5);

        await handler.claimFTM();

        const afterBalance = await ethers.provider.getBalance(deployer);

        // allow for gas
        expect(afterBalance).to.be.approximately(intitialBalance, 15000000000000000000n);
    });

    it("Should be able to claim RAVE after 4 years", async () => {
        const { deployer, handler, tree, elements, rave } = await loadFixture(deployLockerFixture);

        const intitialBalance = await ethers.provider.getBalance(deployer);

        await handler.startLock(100000000, tree.getHexProof(elements[0]), { value: ethers.utils.parseEther("10") });

        await time.increase(YEAR * 4);

        await handler.claimRAVE();

        const afterBalance = await ethers.provider.getBalance(deployer);

        const raveBalance = await rave.balanceOf(deployer);

        expect(raveBalance).to.equal(10000000000000000000000n);
        // allow for gas
        expect(afterBalance).to.be.approximately(intitialBalance, 15000000000000000000n);
    });

    it("Should be able to claim RAVE after 4 years (FTM claimed before)", async () => {
        const { deployer, handler, tree, elements, rave } = await loadFixture(deployLockerFixture);

        const intitialBalance = await ethers.provider.getBalance(deployer);

        await handler.startLock(100000000, tree.getHexProof(elements[0]), { value: ethers.utils.parseEther("10") });

        await time.increase(YEAR * 4);

        await handler.claimFTM();
        await handler.claimRAVE();

        const afterBalance = await ethers.provider.getBalance(deployer);

        const raveBalance = await rave.balanceOf(deployer);

        expect(raveBalance).to.equal(10000000000000000000000n);
        // allow for gas
        expect(afterBalance).to.be.approximately(intitialBalance, 15000000000000000000n);
    });

    it("Should not be able to claim FTM after previous claim", async () => {
        const { deployer, handler, tree, elements, rave } = await loadFixture(deployLockerFixture);

        await handler.startLock(100000000, tree.getHexProof(elements[0]), { value: ethers.utils.parseEther("10") });

        await time.increase(YEAR * 4);

        await handler.claimFTM();
        
        // allow for gas
        await expect(handler.claimFTM()).to.be.revertedWith("You have already claimed your FTM.");
    });

    it("Should not be able to claim RAVE after previous claim", async () => {
        const { deployer, handler, tree, elements, rave } = await loadFixture(deployLockerFixture);

        await handler.startLock(100000000, tree.getHexProof(elements[0]), { value: ethers.utils.parseEther("10") });

        await time.increase(YEAR * 4);

        await handler.claimRAVE();
        
        // allow for gas
        await expect(handler.claimRAVE()).to.be.revertedWith("This lock is inactive.");
    });

    it("BalanceOf should return correct value", async () => {
        const { deployer, handler, tree, elements, rave } = await loadFixture(deployLockerFixture);

        await handler.startLock(100000000, tree.getHexProof(elements[0]), { value: ethers.utils.parseEther("10") });

        const balanceOf = await handler.balanceOf(deployer);
        expect(balanceOf).to.equal(200_000);
    });

    it("Should allow early unlock", async () => {
        const { deployer, handler, tree, elements, rave } = await loadFixture(deployLockerFixture);

        await handler.startLock(100000000, tree.getHexProof(elements[0]), { value: ethers.utils.parseEther("10") });

        await time.increaseTo(1676293200 + YEAR);

        await handler.earlyUnlock();

        const raveBalance = await rave.balanceOf(deployer);
        const treasuryBalance = await rave.balanceOf("0x87f385d152944689f92Ed523e9e5E9Bd58Ea62ef");

        expect(await ethers.provider.getBalance("0x87f385d152944689f92Ed523e9e5E9Bd58Ea62ef")).to.equal(5);
        expect(raveBalance).to.equal((10n ** 18n) * 50_000n);
        expect(treasuryBalance).to.equal((10n ** 18n) * 150_000n);
        
        const lock = await handler.lock(deployer);

        expect(lock[0].active).to.equal(false);
    });
});