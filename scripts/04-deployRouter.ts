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

  const compiledRouter: CompiledContract = json.parse(
    fs
      .readFileSync(
        path.resolve(
          __dirname,
          "../starknet-artifacts/contracts/Router.cairo/Router.json"
        )
      )

      .toString("ascii")
  );

  const {
    code: routerCode,
    address: routerAddress,
    transaction_hash: routerTxHash,
  } = await defaultProvider.deployContract(
    compiledRouter,
    compileCalldata({
      owner_address: addresses.alpha.adminAccount,
    }),
    keys.admin.publicKey //salt
  );

  console.log("Deployed contract with status: ", routerCode);
  console.log("Router is deployed at: ", routerAddress);
  console.log("Transaction hash: ", routerTxHash);
  console.log("get new status: ", `starknet tx_status --hash ${routerTxHash}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
