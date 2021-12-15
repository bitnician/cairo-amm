export const addresses = {
  alpha: {
    adminAccount:
      "0x5705c3c5e03dd01d68077e0b75c5ba8009da7a09c41a69015bcc80b39163c8",
    token0: "0x7d4d0a83ee4f3543b5924efae75ec68c830d6fb6128e0e747e56326bd749f37",
    token1: "0x29366b381ba18c53e9db8a4476e0599c71cb63f001950d094ce23edcd2cd81c",
    token2: "0x253698a62baa3c1fa05d1dc7e250bbc10bf64442a08e616c908b845c85a5409",
    token3: "0x1a3410befb4d9cad619c4c12dabf8f24f11d840021d841b3e770c639ee9f857",
    token4: "0x55db933072e969adfde096b7a3e0c859d3ccf739c099da95db60c5f2b1b538f",
    token5: "0x7015f80e9019e602027b7408121e2bc68cd45ac8f12cc8e42d682123d5b2204",
    token6: "0x4b77dba8a36917a3ce1edf03587c5fbd4d8735b6625e71270ef8a0eeab11736",
    token7: "0x3d29fc568d5a4ff7374e74524ffa162fd72fe6e2b696e1e720a66e388979b82",
    pool01: "0x13eb1074a15a7a9a34d842194d37c19201cc7e45ef062d1a173b347b7dd29f5",
    pool23: "0x1533592be181fe3f9b9c2cf279868e9c6bc38dc26abe5996c73588b41034004",
    pool45: "0x2cafb42db5915591e3e1692116369bf3519f56bf29fc975c352b879a77bb8a7",
    pool67: "0x65da507f8d8c0efe7ff418043a9e35beed25d4379806f7bf33606cfbc1d51c2",
    router: "0x7976ea605908ebb54dc33473e679c96003e5c4827cf2f9b0fa32d8edcbedc75",
  },
  mainNet: {},
};

export const keys = {
  admin: {
    privateKey:
      "0xb696427c0d79c5d28a1fa6f748bae1b98b3f4b86bd1a2505bab144673c856fa9",
    publicKey:
      "0x060d46f8d7ef3d83ed05f3ed9beb91e22f9529289b9d863683fd71eafaf28035",
  },
};

export const pool = {
  token0Balance: "1000000000000000000000", // 1000e18
  token1Balance: "2000000000000000000000", // 2000e18
  amountsSqrt01: "1414213562373095048801", // sqrt(1000e18 * 2000e18)
  token0Decimals: "18",
  token1Decimals: "18",
  token0Symbol: "UNI",
  token1Symbol: "SNX",
  token2Balance: "1000000000", // 1000e6
  token3Balance: "4000000000000000000000", // 4000e18
  amountsSqrt23: "2000000000000000", // sqrt(1000e18 * 2000e18)
  token2Decimals: "6",
  token3Decimals: "18",
  token2Symbol: "USDC",
  token3Symbol: "DAI",
  token4Balance: "5000000000000000000000", // 5000e18
  token5Balance: "1500000000", // 1500e6
  amountsSqrt45: "2738612787525830", // sqrt(1000e18 * 2000e18)
  token4Decimals: "18",
  token5Decimals: "6",
  token4Symbol: "AKRO",
  token5Symbol: "USDC",
  token6Balance: "10000000000000000000000", // 10000e18
  token7Balance: "100000000000000000", // 1e17
  amountsSqrt67: "31622776601683793319", // sqrt(1000e18 * 2000e18)
  token6Decimals: "18",
  token7Decimals: "18",
  token6Symbol: "BTCB",
  token7Symbol: "DAI",
};
