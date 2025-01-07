require("@nomicfoundation/hardhat-toolbox");
require("@nomiclabs/hardhat-ethers");
require("hardhat-deploy");

module.exports = {
  solidity: {
    version: "0.8.27",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    sepolia: {
      url: `https://sepolia.infura.io/v3/YOUR_INFURA_PROJECT_ID`,
      accounts: [`YOUR_PRIVATE_KEY`]
    },
    bloxberg: {
      url: "https://core.bloxberg.org",
      accounts: [`YOUR_PRIVATE_KEY`]
    }
  }
};