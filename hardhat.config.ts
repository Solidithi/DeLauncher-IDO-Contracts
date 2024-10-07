import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-foundry"
import "@nomicfoundation/hardhat-verify";
import dotenv from "dotenv";
dotenv.config();

const SEPOLIA_RPC_URL = process.env.SEPOLIA_RPC_URL || "http://localhost:8545";
const SEPOLIA_PRIVATE_KEY = process.env.SEPOLIA_PRIVATE_KEY || "0x";
const SHIBUYA_PRIVATE_KEY = process.env.SHIBUYA_PRIVATE_KEY || "0x";

const config: HardhatUserConfig = {
  solidity: "0.8.24",
  networks: {
    hardhat: {
      chainId: 1337,
    },
    sepolia: {
      chainId: 11155111,
      url: SEPOLIA_RPC_URL,
      accounts: [SEPOLIA_PRIVATE_KEY],
    },
    shibuya: {
      url: "https://evm.shibuya.astar.network",
      chainId: 81,
      accounts: [SHIBUYA_PRIVATE_KEY],
    }
  },

  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
  sourcify: {
    enabled: true,
  }
};

export default config;
