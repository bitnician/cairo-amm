import fs from "fs";
import path from "path";
import {
  Contract,
  CompiledContract,
  json,
  number,
  hash,
  encode,
  stark,
  ec,
  defaultProvider,
  compileCalldata,
} from "starknet";
import { addresses, keys } from "./data/data";

async function main() {
  // Deploy the Account

  const compiledErc20: CompiledContract = json.parse(
    fs
      .readFileSync(
        path.resolve(
          __dirname,
          "../starknet-artifacts/contracts/test/ERC20.cairo/ERC20.json"
        )
      )

      .toString("ascii")
  );

  const {
    code: token0Code,
    address: token0Address,
    transaction_hash: token0TxHash,
  } = await defaultProvider.deployContract(
    compiledErc20,
    compileCalldata({
      owner: addresses.alpha.adminAccount,
    }),
    keys.admin.publicKey //salt
  );

  console.log("Deployed contract with status: ", token0Code);
  console.log("Token0 is deployed at: ", token0Address);
  console.log("Transaction hash: ", token0TxHash);

  const {
    code: token1Code,
    address: token1Address,
    transaction_hash: token1TxHash,
  } = await defaultProvider.deployContract(
    compiledErc20,
    compileCalldata({
      owner: addresses.alpha.adminAccount,
    }),
    addresses.alpha.adminAccount //salt
  );

  console.log("Deployed contract with status: ", token1Code);
  console.log("Token01 is deployed at: ", token1Address);
  console.log("Transaction hash: ", token1TxHash);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
