import { getAmountOut } from "./utils/helpers";
import { expect } from "chai";
import fs from "fs";
import path from "path";
import { BN } from "bn.js";
import {
  CompiledContract,
  Contract,
  compileCalldata,
  // defaultProvider,
  ec,
  encode,
  hash,
  json,
  number,
  stark,
  uint256,
  Provider,
} from "starknet";
import { starknet } from "hardhat";
import { Signer } from "./utils/Signer";
import { loadFixture } from "@ethereum-waffle/provider";

describe("Pool", function () {
  this.timeout(300_000);

  // let token0Contract: Contract;
  // let token1Contract: Contract;
  // let poolContract: Contract;
  // let accountContract: Contract;
  // let token0Address: string;
  // let token1Address: string;
  // let poolAddress: string;
  // let accountAddress: string;
  // let signer: Signer;

  before(async () => {
    // const defaultProvider = new Provider({ baseUrl: "http://localhost:5000" });
    console.log("create factory");

    const contractFactory = await starknet.getContractFactory("Account");
    console.log("create contract");

    const contract = await contractFactory.deploy({ signer: 1, guardian: 0 });

    console.log("Deployed at", contract.address);

    //   const compiledPool: CompiledContract = json.parse(
    //     fs
    //       .readFileSync(
    //         path.resolve(
    //           __dirname,
    //           "../starknet-artifacts/contracts/Pool.cairo/Pool.json"
    //         )
    //       )
    //       .toString("ascii")
    //   );
    //   const compiledErc20: CompiledContract = json.parse(
    //     fs
    //       .readFileSync(
    //         path.resolve(
    //           __dirname,
    //           "../starknet-artifacts/contracts/test/ERC20.cairo/ERC20.json"
    //         )
    //       )
    //       .toString("ascii")
    //   );
    //   const compiledAccount: CompiledContract = json.parse(
    //     fs
    //       .readFileSync(
    //         path.resolve(
    //           __dirname,
    //           "../starknet-artifacts/contracts/test/Account.cairo/Account.json"
    //         )
    //       )
    //       .toString("ascii")
    //   );

    //   const privateKey =
    //     "0xb696427c0d79c5d28a1fa6f748bae1b98b3f4b86bd1a2505bab144673c856fa9";
    //   signer = new Signer(privateKey);

    //   const {
    //     code: codeAccount,
    //     address: accountAddressLocal,
    //     transaction_hash: accountTxHash,
    //   } = await defaultProvider.deployContract(
    //     compiledAccount,
    //     compileCalldata({
    //       signer: signer.publicKey,
    //       guardian: "0",
    //     }),
    //     signer.publicKey
    //   );

    //   expect(codeAccount).to.eq("TRANSACTION_RECEIVED");
    //   expect(accountAddressLocal).to.not.null;
    //   // await defaultProvider.waitForTx(accountTxHash);

    //   const {
    //     code: codeToken0,
    //     address: token0AddressLocal,
    //     transaction_hash: token0TxHash,
    //   } = await defaultProvider.deployContract(
    //     compiledErc20,
    //     compileCalldata({
    //       owner: accountAddressLocal as string,
    //     }),
    //     signer.publicKey
    //   );
    //   expect(codeToken0).to.eq("TRANSACTION_RECEIVED");
    //   expect(token0AddressLocal).to.not.null;
    //   // await defaultProvider.waitForTx(token0TxHash);

    //   const {
    //     code: codeToken1,
    //     address: token1AddressLocal,
    //     transaction_hash: token1TxHash,
    //   } = await defaultProvider.deployContract(
    //     compiledErc20,
    //     compileCalldata({
    //       owner: accountAddressLocal as string,
    //     })
    //   );
    //   expect(codeToken1).to.eq("TRANSACTION_RECEIVED");
    //   expect(token1AddressLocal).to.not.null;
    //   // await defaultProvider.waitForTx(token1TxHash);

    //   const {
    //     code: codePool,
    //     address: poolAddressLocal,
    //     transaction_hash: poolTxHash,
    //   } = await defaultProvider.deployContract(
    //     compiledPool,
    //     compileCalldata({
    //       token0_address: token0AddressLocal as string,
    //       token1_address: token1AddressLocal as string,
    //     })
    //   );
    //   expect(codePool).to.eq("TRANSACTION_RECEIVED");
    //   expect(poolAddressLocal).to.not.null;
    //   // await defaultProvider.waitForTx(poolTxHash);

    //   // init contracts
    //   token0Contract = new Contract(compiledErc20.abi, token0AddressLocal);
    //   token1Contract = new Contract(compiledErc20.abi, token1AddressLocal);
    //   poolContract = new Contract(compiledPool.abi, poolAddressLocal);
    //   accountContract = new Contract(compiledAccount.abi, accountAddressLocal);

    //   token0Address = token0AddressLocal as string;
    //   token1Address = token1AddressLocal as string;
    //   poolAddress = poolAddressLocal as string;
    //   accountAddress = accountAddressLocal as string;
  });

  describe("#view functions", () => {
    it("should read the view functions", async () => {
      // const { res: token0 } = await poolContract.call("get_token0");
      // const { res: token1 } = await poolContract.call("get_token1");
      // const { reserve0, reserve1 } = await poolContract.call("get_reserves");
      // expect(token0).to.eq(token0Address);
      // expect(token1).to.eq(token1Address);
      // expect(reserve0).to.deep.equal(uint256.bnToUint256("0"));
      // expect(reserve1).to.deep.equal(uint256.bnToUint256("0"));
    });
  });

  // describe("#mint()", () => {
  //   it("should mint token with amountSqrt", async () => {
  //     const token0AmountBN = new BN(100).mul(new BN(10).pow(new BN(18)));
  //     const token1AmountBN = new BN(400).mul(new BN(10).pow(new BN(18)));
  //     const amountSqrtBn = new BN("200000000000000000000");

  //     const token0AmountUint = uint256.bnToUint256(token0AmountBN);
  //     const token1AmountUint = uint256.bnToUint256(token1AmountBN);
  //     const amountSqrtUint = uint256.bnToUint256(amountSqrtBn);
  //     const to = poolAddress;

  //     const { reserve0: initialReserve0, reserve1: initialReserve1 } =
  //       await poolContract.call("get_reserves");

  //     // send tokens to pool
  //     await signer.sendTransaction(accountContract, token0Address, "transfer", [
  //       accountAddress,
  //       token0AmountUint,
  //     ]);
  //     await signer.sendTransaction(accountContract, token1Address, "transfer", [
  //       accountAddress,
  //       token1AmountUint,
  //     ]);

  //     // mint lp token
  //     const code: string = await signer.sendTransaction(
  //       accountContract,
  //       to,
  //       "mint",
  //       [to, amountSqrtUint, poolAddress]
  //     );

  //     const { reserve0: updatedReserve0, reserve1: updatedReserve1 } =
  //       await poolContract.call("get_reserves");

  //     const initialReserve0Bn = uint256.uint256ToBN(initialReserve0 as any);
  //     const initialReserve1Bn = uint256.uint256ToBN(initialReserve1 as any);
  //     const updatedReserve0Bn = uint256.uint256ToBN(updatedReserve0 as any);
  //     const updatedReserve1Bn = uint256.uint256ToBN(updatedReserve1 as any);

  //     expect(updatedReserve0Bn).to.deep.equal(
  //       initialReserve0Bn.add(token0AmountBN)
  //     );
  //     expect(updatedReserve1Bn).to.deep.equal(
  //       initialReserve1Bn.add(token1AmountBN)
  //     );
  //   });

  //   it("should mint token without amountSqrt", async () => {});
  // });
  // describe("#burn()", () => {
  //   it("should burn the tokens", async () => {
  //     const { res: lpTokenBalance } = await poolContract.call("balance_of", {
  //       account: accountAddress,
  //     });
  //     const lpTokenBalanceBN = uint256.uint256ToBN(lpTokenBalance as any);
  //     const lpToBurnBn = lpTokenBalanceBN.div(new BN(2));
  //     const lpToBurnUint = uint256.bnToUint256(lpToBurnBn);

  //     // transfer lp token
  //     // await signer.sendTransaction(accountContract, poolAddress, "transfer", [
  //     //   poolAddress,
  //     //   lpToBurnUint,
  //     // ]);

  //     // burn lp token
  //     // const code: string = await signer.sendTransaction(
  //     //   accountContract,
  //     //   poolAddress,
  //     //   "burn",
  //     //   [accountAddress, poolAddress]
  //     // );
  //   });
  // });
  // describe("#swap()", () => {
  //   it("exact input", async () => {
  //     const { reserve0: initialReserve0, reserve1: initialReserve1 } =
  //       await poolContract.call("get_reserves");

  //     const initialReserve0Bn = uint256.uint256ToBN(initialReserve0 as any);
  //     const initialReserve1Bn = uint256.uint256ToBN(initialReserve1 as any);

  //     const amountInBN = new BN(100).mul(new BN(10).pow(new BN(18)));

  //     const amountOut = getAmountOut(
  //       amountInBN,
  //       initialReserve0Bn,
  //       initialReserve1Bn
  //     );
  //     const amountOutUnit = uint256.bnToUint256(amountOut);

  //     // await signer.sendTransaction(accountContract, token0Address, "transfer", [
  //     //   accountAddress,
  //     //   token0AmountUint,
  //     // ]);

  //     // swap tokens
  //     // const code: string = await signer.sendTransaction(
  //     //   accountContract,
  //     //   poolAddress,
  //     //   "swap",
  //     //   ['0', amountOutUnit,accountAddress,poolAddress]
  //     // );
  //   });
  //   it("exact output", async () => {});
  // });
});
