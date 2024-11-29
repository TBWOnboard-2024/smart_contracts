require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-ignition-ethers");
require("dotenv").config();

const privateKey = process.env.PRIVATE_KEY;

module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.28",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.6.12",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ]
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
