import fs from "fs";
import path from "path";
import {
  Signer,
  defaultProvider,
  Contract,
  CompiledContract,
  json,
} from "starknet";
import { number, hash, encode, stark, ec } from "starknet/dist";
import { addresses, keys } from "./data/data";

async function main() {
  const { admin } = keys;

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

  const account = new Contract(
    compiledArgentAccount.abi,
    addresses.alpha.adminAccount
  );

  const token0 = new Contract(compiledErc20.abi, addresses.alpha.token1);

  const { res: nonceHex } = await account.call("get_nonce");
  const nonce = number.toBN(nonceHex as string).toString();

  const { res: adminBalanceUint256 } = await token0.call("balance_of", {
    account: addresses.alpha.adminAccount,
  });

  let adminBalance: string;
  if (typeof adminBalanceUint256 === "object") {
    adminBalance = Object.entries(adminBalanceUint256)
      .filter(([k]) => k !== "type")
      .map(([, v]) => number.toBN(v).toString())[0];

    console.log(adminBalance);
  }

  // const adminBalance = number.toBN(adminBalanceHex.low as string).toString();

  // console.log(adminBalance);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
