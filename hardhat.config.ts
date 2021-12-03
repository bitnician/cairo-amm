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

export default {
  networks: {
    hardhat: {
      allowUnlimitedContractSize: false,
    },
  },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
  solidity: {
    compilers: [DEFAULT_COMPILER_SETTINGS],
  },
  watcher: {
    test: {
      tasks: [{ command: "test", params: { testFiles: ["{path}"] } }],
      files: ["./test/**/*"],
      verbose: true,
    },
  },
};
