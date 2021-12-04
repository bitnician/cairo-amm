import fs from "fs";
import path from "path";
import {
  Contract,
  CompiledContract,
  json,
  encode,
  hash,
  stark,
  ec,
  number,
  uint256,
} from "starknet";
import { addresses, keys } from "../data/data";

async function main() {
  const compiledArgentAccount: CompiledContract = json.parse(
    fs
      .readFileSync(
        path.resolve(
          __dirname,
          "../../starknet-artifacts/contracts/test/Account.cairo/Account.json"
        )
      )

      .toString("ascii")
  );

  const account = new Contract(
    compiledArgentAccount.abi,
    addresses.alpha.adminAccount
  );

  const adminKeyPair = ec.getKeyPair(keys.admin.privateKey);

  const { nonce } = await account.call("get_nonce");

  const msgHash = encode.addHexPrefix(
    hash.hashMessage(
      account.connectedTo as string,
      addresses.alpha.router,
      stark.getSelectorFromName("approve"),
      [
        addresses.alpha.adminAccount,
        addresses.alpha.token0,
        addresses.alpha.token1,
        "10000000000000000000000000",
        "10000000000000000000000000",
        "10000000000000000000000000",
      ],
      nonce.toString()
    )
  );

  // const msgHash = encode.addHexPrefix(
  //   hash.hashMessage(
  //     account.connectedTo as string,
  //     addresses.alpha.router,
  //     stark.getSelectorFromName("init_liquidity"),
  //     [
  //       addresses.alpha.adminAccount,
  //       addresses.alpha.token0,
  //       addresses.alpha.token1,
  //       "10000000000000000000000000",
  //       "10000000000000000000000000",
  //       "10000000000000000000000000",
  //     ],
  //     nonce.toString()
  //   )
  // );

  // const { r, s } = ec.sign(adminKeyPair, msgHash);

  // const { code, transaction_hash } = await account.invoke(
  //   "execute",
  //   {
  //     to: addresses.alpha.router,
  //     selector: stark.getSelectorFromName("whitelist_pool"),
  //     calldata: [addresses.alpha.pool],
  //     nonce: nonce.toString(),
  //   },
  //   [number.toHex(r), number.toHex(s)]
  // );

  // console.log(
  //   `The pool with address ${addresses.alpha.pool} has been whitelisted`
  // );
  // console.log(`Transaction hash: ${transaction_hash}`);
  // console.log(`Transaction status: ${code}`);
  // console.log(
  //   "get new status: ",
  //   `starknet tx_status --hash ${transaction_hash}`
  // );

  //approve router
  //init liquidity
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
