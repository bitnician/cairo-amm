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
  const { admin, guardian } = keys;

  const adminStarkKeyPair = ec.getKeyPair(admin.privateKey);
  const adminStarkKeyPub = ec.getStarkKey(adminStarkKeyPair);

  const guardianStarkKeyPair = ec.getKeyPair(guardian.privateKey);
  const guardianStarkKeyPub = ec.getStarkKey(guardianStarkKeyPair);

  console.log("The admin private key is ", admin.privateKey);
  console.log("The admin public key is ", adminStarkKeyPub);

  console.log("The guardian private key is ", guardian.privateKey);
  console.log("The guardian public key is ", guardianStarkKeyPub);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
