import fs from "fs";
import {
  Signer,
  defaultProvider,
  Contract,
  CompiledContract,
  json,
} from "starknet";
import { ec } from "starknet/dist";
import { keys } from "./data";

async function main() {
  const { admin } = keys;

  const adminStarkKeyPair = ec.getKeyPair(admin.privateKey);
  const adminStarkKeyPub = ec.getStarkKey(adminStarkKeyPair);

  console.log("The admin private key is ", admin.privateKey);
  console.log("The admin public key is ", adminStarkKeyPub);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
