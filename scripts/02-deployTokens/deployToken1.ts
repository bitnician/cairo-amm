import { symbolToFelt } from "../utils/symbol";
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
import { addresses, keys, pool } from "../data/data";

async function main() {
  // Deploy the Account

  const compiledErc20: CompiledContract = json.parse(
    fs
      .readFileSync(
        path.resolve(
          __dirname,
          "../../starknet-artifacts/contracts/test/ERC20.cairo/ERC20.json"
        )
      )

      .toString("ascii")
  );

  const symbol = symbolToFelt(pool.token1Symbol);

  const {
    code: token1Code,
    address: token1Address,
    transaction_hash: token1TxHash,
  } = await defaultProvider.deployContract(
    compiledErc20,
    compileCalldata({
      _owner: addresses.alpha.adminAccount,
      _symbol: symbol,
      _decimals: pool.token1Decimals,
    }),
    keys.admin.publicKey //salt
  );

  console.log("Deployed contract with status: ", token1Code);
  console.log("Token1 is deployed at: ", token1Address);
  console.log("Transaction hash: ", token1TxHash);
  console.log("get new status: ", `starknet tx_status --hash ${token1TxHash}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
