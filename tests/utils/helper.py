
def getAmountIn(amountOut, reserveIn, reserve_out):

    numerator = reserveIn[0] * amountOut[0] * 1000
    denominator = (reserve_out[0] - amountOut[0]) * 997
    amountIn = (numerator // denominator) + 1

    return (amountIn, 0)


def getAmountOut(amountIn, reserveIn, reserve_out):

    amountInWithFee = amountIn[0] * 997
    numerator = amountInWithFee * reserve_out[0]
    denominator = (reserveIn[0] * 1000) + amountInWithFee
    amountOut = (numerator // denominator)

    return (amountOut, 0)


def str_to_felt(text):
    b_text = bytes(text, 'UTF-8')
    return int.from_bytes(b_text, "big")


def uint(a):
    return(a, 0)


async def assert_revert(fun):
    try:
        await fun
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED
