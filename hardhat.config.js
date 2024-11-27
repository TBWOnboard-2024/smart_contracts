require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-ignition-ethers");
require("dotenv").config();

const privateKey = process.env.PRIVATE_KEY;

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.28",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },

  networks: {
    sepolia: {
      url: `https://sepolia.drpc.org`,
      accounts: [privateKey],
    },
    BSC_Testnet: {
      url: "https://bsc-testnet-dataseed.bnbchain.org",
      accounts:[privateKey],
    },
    BSC_Mainnet: {
      url: "https://bsc-dataseed.bnbchain.org",
      accounts: [privateKey],
    },
  },

  sourcify: {
    enabled: false
  },

  etherscan: {
    apiKey: process.env.ETHERSCAN_API,
  },
};
