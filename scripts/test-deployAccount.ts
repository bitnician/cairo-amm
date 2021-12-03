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

  const token0 = new Contract(compiledErc20.abi, addresses.alpha.token0);

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

    const msgHash = encode.addHexPrefix(
      hash.hashMessage(
        account.connectedTo,
        addresses.alpha.token0,
        stark.getSelectorFromName("transfer"),
        [addresses.alpha.token0, "10"],
        nonce.toString()
      )
    );

    const starkKeyPair = ec.getKeyPair(admin.privateKey);

    const { r, s } = ec.sign(starkKeyPair, msgHash);

    // const { code, transaction_hash } = await account.invoke(
    //   "execute",
    //   {
    //     to: addresses.alpha.token0,
    //     selector: stark.getSelectorFromName("transfer"),
    //     calldata: [erc20Address, "10"],
    //     nonce: nonce.toString(),
    //   },
    //   [number.toHex(r), number.toHex(s)]
    // );
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
