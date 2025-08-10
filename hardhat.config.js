require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-verify");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.19",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      },
      viaIR: true
    }
  },
  networks: {
    hardhat: {
      mining: {
        auto: true,
        interval: [1000, 3000]  // Random interval between 1-3 seconds
      },
      chainId: 31337
    },
    // Add other networks as needed
  }
}; 