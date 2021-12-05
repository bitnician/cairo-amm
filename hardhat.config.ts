import "@typechain/hardhat";
import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-etherscan";
import "@shardlabs/starknet-hardhat-plugin";

import env from "dotenv";
env.config();

const DEFAULT_COMPILER_SETTINGS = {
  version: "0.8.6",
  settings: {
    optimizer: {
      enabled: true,
      runs: 1_000_000,
    },
    metadata: {
      bytecodeHash: "none",
    },
  },
};

const PRIVATE_KEY = process.env.PRIVATE_KEY;

// export default {
//   networks: {
//     devnet: {
//       url: "http://localhost:5000",
//     },
//     hardhat: {
//       allowUnlimitedContractSize: false,
//     },
//   },
//   mocha: {
//     starknetNetwork: "devnet",
//   },
//   etherscan: {
//     // Your API key for Etherscan
//     // Obtain one at https://etherscan.io/
//     apiKey: process.env.ETHERSCAN_API_KEY,
//   },
//   solidity: {
//     compilers: [DEFAULT_COMPILER_SETTINGS],
//   },
//   cairo: {
//     version: "0.6.1",
//   },

//   watcher: {
//     test: {
//       tasks: [{ command: "test", params: { testFiles: ["{path}"] } }],
//       files: ["./test/**/*"],
//       verbose: true,
//     },
//   },
// };

module.exports = {
  cairo: {
    version: "0.6.1",
  },
  networks: {
    devnet: {
      url: "http://localhost:5000",
    },
  },
  // Delete it if you want to test with starknet alpha
  mocha: {
    starknetNetwork: "devnet",
  },
};
