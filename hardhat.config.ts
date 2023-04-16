import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@matterlabs/hardhat-zksync-deploy";
import "@matterlabs/hardhat-zksync-solc";
import "@openzeppelin/hardhat-upgrades";
import "hardhat-contract-sizer";
import * as dotenv from "dotenv";
dotenv.config()

const config: HardhatUserConfig = {
  zksolc: {
    version: "1.3.5",
    compilerSource: "binary",
    settings: {},
  },

  networks: {
    zkSyncTestnet: {
      url: "https://zksync2-testnet.zksync.dev",
      ethNetwork: "goerli", // Can also be the RPC URL of the network (e.g. `https://goerli.infura.io/v3/<API_KEY>`)
      zksync: true,
      accounts: process.env.DEPLOYER_PK ? [process.env.DEPLOYER_PK] : undefined
    },
    zkSyncEra: {
      url: "https://mainnet.era.zksync.io",
      ethNetwork: "mainnet",
      zksync: true,
      accounts: process.env.DEPLOYER_PK ? [process.env.DEPLOYER_PK] : undefined
    },
    fantom: {
      url: "https://rpc.ftm.tools",
      accounts: process.env.DEPLOYER_PK ? [process.env.DEPLOYER_PK] : undefined
    },
    fantomTest: {
      url: "https://rpc.testnet.fantom.network",
      accounts: process.env.DEPLOYER_PK ? [process.env.DEPLOYER_PK] : undefined
    },
  },

  solidity: {
    version: "0.8.19",
    settings: {
      optimizer: {
        enabled: true,
        runs: 20,
      }
    }
  },

  etherscan: {
    apiKey: process.env.ETHERSCAN,
  },

  viaIR: true,

  contractSizer: {
    alphaSort: true,
    disambiguatePaths: false,
    runOnCompile: true,
    strict: true,
    outputFile: "sizes.log",
    // @ts-ignore an issue in the contract sizer types
    unit: "B"
  }
};

export default config;
