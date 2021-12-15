import { pool } from "../data/data";
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
      stark.getSelectorFromName("init_liquidity"),
      [
        addresses.alpha.adminAccount,
        addresses.alpha.token4,
        addresses.alpha.token5,
        pool.token4Balance,
        "0",
        pool.token5Balance,
        "0",
        pool.amountsSqrt45,
        "0",
      ],
      nonce.toString()
    )
  );

  const { r, s } = ec.sign(adminKeyPair, msgHash);

  const { code, transaction_hash } = await account.invoke(
    "execute",
    {
      to: addresses.alpha.router,
      selector: stark.getSelectorFromName("init_liquidity"),
      calldata: [
        addresses.alpha.adminAccount,
        addresses.alpha.token4,
        addresses.alpha.token5,
        pool.token4Balance,
        "0",
        pool.token5Balance,
        "0",
        pool.amountsSqrt45,
        "0",
      ],
      nonce: nonce.toString(),
    },
    [number.toHex(r), number.toHex(s)]
  );

  console.log(
    `The pool with address ${addresses.alpha.pool45} has been whitelisted`
  );
  console.log(`Transaction hash: ${transaction_hash}`);
  console.log(`Transaction status: ${code}`);
  console.log(
    "get new status: ",
    `starknet tx_status --hash ${transaction_hash}`
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
