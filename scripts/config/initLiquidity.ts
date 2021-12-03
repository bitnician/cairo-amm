import fs from "fs";
import path from "path";
import {
  Signer,
  defaultProvider,
  Contract,
  CompiledContract,
  json,
} from "starknet";
import { number } from "starknet/dist";
import { addresses } from "../data/data";

async function main() {
  //approve router
  //init liquidity
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
