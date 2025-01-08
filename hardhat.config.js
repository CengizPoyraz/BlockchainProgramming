
/* global ethers task */
require('@nomiclabs/hardhat-waffle')
require("hardhat-deploy");
// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task('accounts', 'Prints the list of accounts', async () => {
  const accounts = await ethers.getSigners()

  for (const account of accounts) {
    console.log(account.address)
  }
})

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: '0.8.6',
  defaultNetwork: "sepolia",
  settings: {
    optimizer: {
      enabled: true,
      runs: 200
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
}
