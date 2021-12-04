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

  const compiledPool: CompiledContract = json.parse(
    fs
      .readFileSync(
        path.resolve(
          __dirname,
          "../starknet-artifacts/contracts/Pool.cairo/Pool.json"
        )
      )

      .toString("ascii")
  );

  const {
    code: poolCode,
    address: poolAddress,
    transaction_hash: poolTxHash,
  } = await defaultProvider.deployContract(
    compiledPool,
    compileCalldata({
      token0_address: addresses.alpha.token0,
      token1_address: addresses.alpha.token1,
    }),
    keys.admin.publicKey //salt
  );

  console.log("Deployed contract with status: ", poolCode);
  console.log("Pool is deployed at: ", poolAddress);
  console.log("Transaction hash: ", poolTxHash);
  console.log("get new status: ", `starknet tx_status --hash ${poolTxHash}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
