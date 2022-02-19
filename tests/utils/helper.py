from starkware.starkware_utils.error_handling import StarkException
from starkware.starknet.definitions.error_codes import StarknetErrorCode


def get_amount_in(amount_out, reserve_in, reserve_out):

    numerator = reserve_in[0] * amount_out[0] * 1000
    denominator = (reserve_out[0] - amount_out[0]) * 997
    amount_in = (numerator // denominator) + 1

    return (amount_in, 0)


def get_amount_out(amount_in, reserve_in, reserve_out):

    amount_in_with_fee = amount_in[0] * 997
    numerator = amount_in_with_fee * reserve_out[0]
    denominator = (reserve_in[0] * 1000) + amount_in_with_fee
    amount_out = (numerator // denominator)

    return (amount_out, 0)


def str_to_felt(text):
    b_text = bytes(text, 'UTF-8')
    return int.from_bytes(b_text, "big")


def uint(num):
    return(num, 0)


async def assert_revert(fun):
    try:
        await fun
        assert False
    except StarkException as err:
        _, error = err.args  # pylint: disable=unbalanced-tuple-unpacking
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED
