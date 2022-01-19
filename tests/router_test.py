import os
import math
import pytest
import asyncio

from starkware.starknet.testing.starknet import Starknet
from starkware.starkware_utils.error_handling import StarkException
from starkware.starknet.definitions.error_codes import StarknetErrorCode
from utils.Signer import Signer
from utils.helper import getAmountIn, getAmountOut, uint, str_to_felt, assert_revert


pool_creator_private_key = 123456789987654321
deployer_private_key = 987654321987654321
swapper_private_key = 543215678954321567

pool_creator = Signer(pool_creator_private_key)
deployer = Signer(deployer_private_key)
swapper = Signer(swapper_private_key)


token_0_amount = uint(1000000)
token_1_amount = uint(4000000)
amountsSqrt = uint(2000000)


@pytest.fixture(scope="module")
def event_loop():
    return asyncio.new_event_loop()


@pytest.fixture(scope="module")
async def contract_factory():

    ROUTER_CONTRACT_FILE = os.path.join(
        os.path.dirname(__file__), "../contracts/Router.cairo"
    )

    ERC20_CONTRACT_FILE = os.path.join(
        os.path.dirname(__file__), "../contracts/test/ERC20.cairo"
    )

    ACCOUNT_CONTRACT_FILE = os.path.join(
        os.path.dirname(__file__), "../contracts/test/Account.cairo"
    )

    starknet = await Starknet.empty()

    pool_creator_account = await starknet.deploy(
        source=ACCOUNT_CONTRACT_FILE, constructor_calldata=[
            pool_creator.public_key, 0]
    )

    deployer_account = await starknet.deploy(
        source=ACCOUNT_CONTRACT_FILE, constructor_calldata=[
            deployer.public_key, 0]
    )

    swapper_account = await starknet.deploy(
        source=ACCOUNT_CONTRACT_FILE, constructor_calldata=[
            swapper.public_key, 0]
    )

    token_0 = await starknet.deploy(
        source=ERC20_CONTRACT_FILE,
        constructor_calldata=[str_to_felt("Token0"), str_to_felt(
            "TOK0"), 18, *uint(100000000000000000000000), deployer_account.contract_address],
    )

    token_1 = await starknet.deploy(
        source=ERC20_CONTRACT_FILE,
        constructor_calldata=[str_to_felt("Token1"), str_to_felt(
            "TOK1"), 18, *uint(100000000000000000000000), deployer_account.contract_address],
    )

    router = await starknet.deploy(
        source=ROUTER_CONTRACT_FILE,
        constructor_calldata=[deployer_account.contract_address],
    )

    return (
        starknet,
        router,
        token_0,
        token_1,
        pool_creator_account,
        deployer_account,
        swapper_account,
    )


async def whitelistPool(contract_factory):
    (
        starknet,
        router,
        token_0,
        token_1,
        pool_creator_account,
        deployer_account,
        swapper_account,
    ) = contract_factory

    POOL_CONTRACT_FILE = os.path.join(
        os.path.dirname(__file__), "../contracts/Pool.cairo"
    )

    pool = await starknet.deploy(
        source=POOL_CONTRACT_FILE,
        constructor_calldata=[
            token_0.contract_address,
            token_1.contract_address,
        ],
    )

    await deployer.send_transaction(
        deployer_account,
        router.contract_address,
        "whitelistPool",
        [pool.contract_address],
    )

    return pool


async def addLiquidity(
    contract_factory, token_0_amount, token_1_amount, amountsSqrt=uint(0)
):
    (
        starknet,
        router,
        token_0,
        token_1,
        pool_creator_account,
        deployer_account,
        swapper_account,
    ) = contract_factory

    spender = router.contract_address
    # set approve
    await deployer.send_transaction(
        deployer_account,
        token_0.contract_address,
        "approve",
        [spender, *token_0_amount],
    )

    await deployer.send_transaction(
        deployer_account,
        token_1.contract_address,
        "approve",
        [spender, *token_1_amount],
    )

    if amountsSqrt == uint(0):
        # add liquidity
        await deployer.send_transaction(
            deployer_account,
            router.contract_address,
            "addLiquidity",
            [
                token_0.contract_address,
                token_1.contract_address,
                *token_0_amount,
                *token_1_amount,
            ],
        )
    else:
        # init liquidity
        await deployer.send_transaction(
            deployer_account,
            router.contract_address,
            "initLiquidity",
            [
                deployer_account.contract_address,
                token_0.contract_address,
                token_1.contract_address,
                *token_0_amount,
                *token_1_amount,
                *amountsSqrt,
            ],
        )


@pytest.mark.asyncio
async def test_whitelistPool(contract_factory):
    (
        starknet,
        router,
        token_0,
        token_1,
        pool_creator_account,
        deployer_account,
        swapper_account,
    ) = contract_factory

    pool = await whitelistPool(contract_factory)

    execution_result = await router.getPoolAddress(
        token_0.contract_address, token_1.contract_address
    ).call()
    assert execution_result.result.address == pool.contract_address

    execution_result = await router.getPoolAddress(
        token_1.contract_address, token_0.contract_address
    ).call()
    assert execution_result.result.address == pool.contract_address

    await router.verifyPoolIsWhitelisted(pool.contract_address).call()

    assert_revert(router.verifyPoolIsWhitelisted(123).call())


@pytest.mark.asyncio
async def test_initLiquidity(contract_factory):
    (
        starknet,
        router,
        token_0,
        token_1,
        pool_creator_account,
        deployer_account,
        swapper_account,
    ) = contract_factory

    pool = await whitelistPool(contract_factory)

    lp_token0_initial_balance = await token_0.balanceOf(
        deployer_account.contract_address
    ).call()
    lp_token1_initial_balance = await token_1.balanceOf(
        deployer_account.contract_address
    ).call()

    await addLiquidity(contract_factory, token_0_amount, token_1_amount, amountsSqrt)

    lp_token0_updated_balance = await token_0.balanceOf(
        deployer_account.contract_address
    ).call()
    lp_token1_updated_balance = await token_1.balanceOf(
        deployer_account.contract_address
    ).call()

    assert lp_token0_updated_balance.result.balance == uint(
        lp_token0_initial_balance.result.balance[0] - token_0_amount[0]
    )
    assert lp_token1_updated_balance.result.balance == uint(
        lp_token1_initial_balance.result.balance[0] - token_1_amount[0]
    )

    execution_info = await token_0.balanceOf(pool.contract_address).call()
    assert execution_info.result.balance == token_0_amount

    execution_info = await token_1.balanceOf(pool.contract_address).call()
    assert execution_info.result.balance == token_1_amount

    execution_info = await pool.balanceOf(deployer_account.contract_address).call()
    assert execution_info.result.balance == amountsSqrt


@pytest.mark.asyncio
async def test_removeLiquidity(contract_factory):
    (
        starknet,
        router,
        token_0,
        token_1,
        pool_creator_account,
        deployer_account,
        swapper_account,
    ) = contract_factory

    pool = await whitelistPool(contract_factory)

    await addLiquidity(contract_factory, token_0_amount, token_1_amount, amountsSqrt)

    amount_a_min = uint(token_0_amount[0] - 100)
    amount_b_min = uint(token_1_amount[0] - 100)
    spender = router.contract_address

    lp_token0_initial_balance = await token_0.balanceOf(
        deployer_account.contract_address
    ).call()
    lp_token1_initial_balance = await token_1.balanceOf(
        deployer_account.contract_address
    ).call()

    await deployer.send_transaction(
        deployer_account, pool.contract_address, "approve", [
            spender, *amountsSqrt]
    )

    await deployer.send_transaction(
        deployer_account,
        router.contract_address,
        "removeLiquidity",
        [
            token_0.contract_address,
            token_1.contract_address,
            *amountsSqrt,
            *amount_a_min,
            *amount_b_min,
            deployer_account.contract_address,
        ],
    )

    lp_token0_updated_balance = await token_0.balanceOf(
        deployer_account.contract_address
    ).call()
    lp_token1_updated_balance = await token_1.balanceOf(
        deployer_account.contract_address
    ).call()

    execution_info = await pool.balanceOf(deployer_account.contract_address).call()
    assert execution_info.result.balance == uint(0)

    assert lp_token0_updated_balance.result.balance == uint(
        lp_token0_initial_balance.result.balance[0] + token_0_amount[0]
    )
    assert lp_token1_updated_balance.result.balance == uint(
        lp_token1_initial_balance.result.balance[0] + token_1_amount[0]
    )


@pytest.mark.asyncio
async def test_getAmountIn(contract_factory):
    (
        starknet,
        router,
        token_0,
        token_1,
        pool_creator_account,
        deployer_account,
        swapper_account,
    ) = contract_factory

    amountOut = uint(100)
    amountIn = getAmountIn(amountOut, token_0_amount, token_1_amount)

    pool = await whitelistPool(contract_factory)
    await addLiquidity(contract_factory, token_0_amount, token_1_amount, amountsSqrt)

    execution_info = await router.getAmountIn(
        token_0.contract_address, token_1.contract_address, amountOut
    ).call()
    assert execution_info.result.amountIn == amountIn


@pytest.mark.asyncio
async def test_getAmountOut(contract_factory):
    (
        starknet,
        router,
        token_0,
        token_1,
        pool_creator_account,
        deployer_account,
        swapper_account,
    ) = contract_factory

    amountIn = uint(100)
    amountOut = getAmountOut(amountIn, token_0_amount, token_1_amount)

    pool = await whitelistPool(contract_factory)
    await addLiquidity(contract_factory, token_0_amount, token_1_amount, amountsSqrt)

    execution_info = await router.getAmountOut(
        token_0.contract_address, token_1.contract_address, amountIn
    ).call()
    assert execution_info.result.amountOut == amountOut


@pytest.mark.asyncio
async def test_exactInput(contract_factory):
    (
        starknet,
        router,
        token_0,
        token_1,
        pool_creator_account,
        deployer_account,
        swapper_account,
    ) = contract_factory

    pool = await whitelistPool(contract_factory)

    await addLiquidity(contract_factory, token_0_amount, token_1_amount, amountsSqrt)

    amountIn = uint(100)
    tokenIn = token_0.contract_address
    tokenOut = token_1.contract_address
    spender = router.contract_address
    amountOut = getAmountOut(amountIn, token_0_amount, token_1_amount)
    amountOutMin = uint(80)

    # Increase swapper balance by transfering tokenIn from pool_creator to swapper
    await deployer.send_transaction(
        deployer_account,
        tokenIn,
        "transfer",
        [swapper_account.contract_address, *amountIn],
    )

    # Approve tokenIn
    await swapper.send_transaction(
        swapper_account, tokenIn, "approve", [spender, *amountIn]
    )

    # Get swapper initial balances
    execution_info = await token_0.balanceOf(swapper_account.contract_address).call()
    tokenIn_initial_balance = execution_info.result.balance
    execution_info = await token_1.balanceOf(swapper_account.contract_address).call()
    tokenOut_initial_balance = execution_info.result.balance

    # Swap tokenIn for tokenOut
    await swapper.send_transaction(
        swapper_account,
        router.contract_address,
        "exactInput",
        [tokenIn, tokenOut, *amountIn, *amountOutMin],
    )

    # Get swapper balance after swap
    execution_info = await token_0.balanceOf(swapper_account.contract_address).call()
    assert execution_info.result.balance == uint(
        tokenIn_initial_balance[0] - amountIn[0])
    execution_info = await token_1.balanceOf(swapper_account.contract_address).call()
    assert execution_info.result.balance == uint(
        tokenOut_initial_balance[0] + amountOut[0]
    )
