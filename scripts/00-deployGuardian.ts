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
  // Deploy the Guardian

  const compiledGuardian: CompiledContract = json.parse(
    fs
      .readFileSync(
        path.resolve(
          __dirname,
          "../starknet-artifacts/contracts/test/SCSKGuardian.cairo/SCSKGuardian.json"
        )
      )

      .toString("ascii")
  );

  const {
    code: guardianCode,
    address: guardianAddress,
    transaction_hash: guardianTxHash,
  } = await defaultProvider.deployContract(
    compiledGuardian,
    compileCalldata({
      signer: keys.guardian.publicKey,
    }),
    keys.admin.publicKey
  );

  console.log("Deployed contract with status: ", guardianCode);
  console.log("Guardian is deployed at: ", guardianAddress);
  console.log("Transaction hash: ", guardianTxHash);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
