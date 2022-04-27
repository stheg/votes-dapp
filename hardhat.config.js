const { task } = require("hardhat/config");

require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require("solidity-coverage");
require("dotenv").config();
require("./tasks/VotingTasks");

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address, await account.getBalance());
  }
});

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    version: "0.8.13",
    //settings: { optimizer: { enabled: true } }
  },
  networks: {
    rinkeby: {
      url: `https://eth-rinkeby.alchemyapi.io/v2/${process.env.ALC_KEY}`,
      accounts: [process.env.ACC_1, process.env.ACC_2]
    },
    hardhat: {
      chainId: 1337
    }
  },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: process.env.ETHER_SCAN_KEY
  }
};
