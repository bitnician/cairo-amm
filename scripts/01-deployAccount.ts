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

  const compiledArgentAccount: CompiledContract = json.parse(
    fs
      .readFileSync(
        path.resolve(
          __dirname,
          "../starknet-artifacts/contracts/test/Account.cairo/Account.json"
        )
      )

      .toString("ascii")
  );

  const {
    code: accountCode,
    address: accountAddress,
    transaction_hash: accountTxHash,
  } = await defaultProvider.deployContract(
    compiledArgentAccount,
    compileCalldata({
      signer: keys.admin.publicKey,
      guardian: "0",
    }),
    addresses.alpha.adminAccount //salt
  );

  console.log("Deployed contract with status: ", accountCode);
  console.log("Account is deployed at: ", accountAddress);
  console.log("Transaction hash: ", accountTxHash);
  console.log("get new status: ", `starknet tx_status --hash ${accountTxHash}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
