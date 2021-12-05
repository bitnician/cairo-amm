import {
  CompiledContract,
  Contract,
  compileCalldata,
  defaultProvider,
  ec,
  encode,
  hash,
  json,
  number,
  stark,
  uint256,
  KeyPair,
} from "starknet";
import BN from "bn.js";

export const getAmountIn = (
  amountOut: BN,
  reserveIn: BN,
  reserveOut: BN
): BN => {
  const numerator = reserveIn.mul(amountOut).mul(new BN(1000));
  const denominator = reserveOut.sub(amountOut).mul(new BN(997));
  const amountIn = numerator.div(denominator).add(new BN(1));
  return amountIn;
};

export const getAmountOut = (
  amountIn: BN,
  reserveIn: BN,
  reserveOut: BN
): BN => {
  const amountInWithFee = amountIn.mul(new BN(997));
  const numerator = amountInWithFee.mul(reserveOut);
  const denominator = reserveIn.mul(new BN(1000)).add(amountInWithFee);
  const amountOut = numerator.div(denominator);
  return amountOut;
};
