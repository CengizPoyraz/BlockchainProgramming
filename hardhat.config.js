require("@nomicfoundation/hardhat-toolbox");
<<<<<<< HEAD
require("@nomicfoundation/hardhat-ethers");
=======
require("@nomiclabs/hardhat-ethers");
>>>>>>> aa5770cf5e84283289821233af78c546b472e7b0
require("hardhat-deploy");

module.exports = {
  solidity: {
<<<<<<< HEAD
    version: "0.8.28",
=======
    version: "0.8.27",
>>>>>>> aa5770cf5e84283289821233af78c546b472e7b0
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
<<<<<<< HEAD
};
=======
};
>>>>>>> aa5770cf5e84283289821233af78c546b472e7b0
