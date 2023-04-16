import { ethers, upgrades } from "hardhat";
import { AirdropHandler__factory } from "../typechain-types";

const one = async () => {
    const [deployer] = await ethers.getSigners();

    console.log(`Deploying contracts with the account: https://ftmscan.com/address/${deployer.address}`);
  
    console.log("Account balance:", (await deployer.getBalance()).toString());
  
    const Handler = await ethers.getContractFactory("AirdropHandler");

    // const MockERC20 = await ethers.getContractFactory("MockERC20");
    // const mock = await MockERC20.deploy(10000, deployer.address);

    const inputs = ["0x88888a335b1F65a79Ec56A610D865b8b25B6060B", "0x133a125d175ac33f5f9943fcf3c207e05733fbc4ccc8c4aa25e12dae92792c51"];

    const instance = await upgrades.deployProxy(Handler, inputs);
    console.log(`Proxy address: https://ftmscan.com/address/${instance.address}`);

    const upgradedTo = await upgrades.upgradeProxy(instance.address, Handler);
}

const two = async (proxyAddress: string) => {
  const Handler = await ethers.getContractFactory("AirdropHandler");
  const upgradedTo = await upgrades.upgradeProxy(proxyAddress, Handler);

  console.log(`Upgraded: https://ftmscan.com/address/${upgradedTo.address}`);
}

const main = async () => {
  // const proxy = await ethers.getContractAt("AirdropHandler", "0xb5E0f83979dea4Ce385B3737533b3924790DfF86");
  // console.log((await proxy.sendFTM({value: ethers.utils.parseEther("0.01")})).hash);
  // return
  if (true) {
    await two("0xb5E0f83979dea4Ce385B3737533b3924790DfF86");
  } else {
    await one();
  }
} 

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });