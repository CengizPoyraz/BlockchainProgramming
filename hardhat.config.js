require("@nomicfoundation/hardhat-toolbox");
require("@nomiclabs/hardhat-ethers");
require("hardhat-deploy");

module.exports = {
  solidity: {
    version: "0.8.27",
    defaultNetwork: "sepolia",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    sepolia: {
      url: `https://sepolia.infura.io/v3/30b6d251b1dc45219c7a95a807cd4d2e`,
      accounts: [`7a2c62bfe50ccff7e4100dbd142e506df92a52906f79f986a9ba7ffd6143c97d`]
    },
    // bloxberg: {
    //   url: "https://core.bloxberg.org",
    //   accounts: [`YOUR_PRIVATE_KEY`]
    // }
  }
};