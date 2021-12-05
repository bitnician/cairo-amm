import {
  Contract,
  defaultProvider,
  ec,
  encode,
  hash,
  KeyPair,
  number,
  stark,
} from "starknet";

export class Signer {
  public privateKey: string = "";
  public publicKey: string = "";
  public keyPair: KeyPair;

  constructor(privateKey: string) {
    this.privateKey = privateKey;
    this.keyPair = ec.getKeyPair(this.privateKey);
    this.publicKey = ec.getStarkKey(this.keyPair);
  }

  public async sendTransaction(
    account: Contract,
    to: string,
    selectorName: string,
    args: string[]
  ): Promise<string> {
    const { nonce } = await account.call("get_nonce");

    const msgHash = encode.addHexPrefix(
      hash.hashMessage(
        account.connectedTo as string,
        to,
        stark.getSelectorFromName(selectorName),
        args,
        nonce.toString()
      )
    );

    const { r, s } = ec.sign(this.keyPair, msgHash);

    const { code, transaction_hash } = await account.invoke(
      "execute",
      {
        to,
        selector: stark.getSelectorFromName(selectorName),
        calldata: args,
        nonce: nonce.toString(),
      },
      [number.toHex(r), number.toHex(s)]
    );

    await defaultProvider.waitForTx(transaction_hash);

    return code;
  }
}
