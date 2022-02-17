# pylint: disable=invalid-name
from starkware.crypto.signature.signature import private_to_stark_key, sign
from starkware.starknet.public.abi import get_selector_from_name
from starkware.cairo.common.hash_state import compute_hash_on_elements


class Signer():
    def __init__(self, private_key):
        self.private_key = private_key
        self.public_key = private_to_stark_key(private_key)

    def sign(self, message_hash):
        return sign(msg_hash=message_hash, priv_key=self.private_key)

    async def send_transaction(self, account, recipient_address, selector_name, calldata, nonce=None):  # pylint: disable=too-many-arguments
        if nonce is None:
            execution_info = await account.get_nonce().call()
            nonce, = execution_info.result

        selector = get_selector_from_name(selector_name)
        message_hash = hash_message(
            account.contract_address, recipient_address, selector, calldata, nonce)
        sig_r, sig_s = self.sign(message_hash)

        return await account.execute(recipient_address, selector, calldata, nonce).invoke(signature=[sig_r, sig_s])


def hash_message(sender, recipient_address, selector, calldata, nonce):
    message = [
        sender,
        recipient_address,
        selector,
        compute_hash_on_elements(calldata),
        nonce
    ]
    return compute_hash_on_elements(message)
