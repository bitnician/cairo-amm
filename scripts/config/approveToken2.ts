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
import { addresses, keys, pool } from "../data/data";

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
      addresses.alpha.token2,
      stark.getSelectorFromName("approve"),
      [addresses.alpha.router, pool.token2Balance, "0"],
      nonce.toString()
    )
  );

  const { r, s } = ec.sign(adminKeyPair, msgHash);

  const { code, transaction_hash } = await account.invoke(
    "execute",
    {
      to: addresses.alpha.token2,
      selector: stark.getSelectorFromName("approve"),
      calldata: [addresses.alpha.router, pool.token2Balance, "0"],
      nonce: nonce.toString(),
    },
    [number.toHex(r), number.toHex(s)]
  );

  console.log(`Transaction hash approve tx for token 2: ${transaction_hash}`);
  console.log(`Transaction status approve tx for token 2: ${code}`);
  console.log(
    "get new status approve tx for token 2: ",
    `starknet tx_status --hash ${transaction_hash}`
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
