import asyncio
import pytest

from utils.helper import get_amount_in, get_amount_out, uint
from fixture import router_fixture, deploy_pool, get_signers


token_0_amount = uint(1000000)
token_1_amount = uint(4000000)
amounts_sqrt = uint(2000000)


@pytest.fixture(scope="module")
def event_loop():
    return asyncio.new_event_loop()


@pytest.fixture(scope="module")
async def contract_factory():

    starknet, deployer_account, swapper_account, token_0, token_1, pool, router = await router_fixture()
    return starknet, deployer_account, swapper_account, token_0, token_1, pool, router


async def whitelist_pool(contract_factory):
    (
        starknet, deployer_account, _, token_0, token_1, pool, router
    ) = contract_factory

    deployer, _ = get_signers()

    pool = await deploy_pool(starknet=starknet, token_0=token_0.contract_address, token_1=token_1.contract_address)

    await deployer.send_transaction(
        deployer_account,
        router.contract_address,
        "whitelistPool",
        [pool.contract_address],
    )

    return pool


async def add_liquidity(
    contract_factory, token_0_amount, token_1_amount, init=False
):
    (
        _, deployer_account, _, token_0, token_1, _, router
    ) = contract_factory

    deployer, _ = get_signers()

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

    if init:
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
            ],
        )
    else:
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


@pytest.mark.asyncio
async def test_whitelist_pool(contract_factory):
    (
        _, _, _, token_0, token_1, pool, router
    ) = contract_factory

    pool = await whitelist_pool(contract_factory)

    execution_result = await router.getPoolAddress(
        token_0.contract_address, token_1.contract_address
    ).call()
    assert execution_result.result.address == pool.contract_address

    execution_result = await router.getPoolAddress(
        token_1.contract_address, token_0.contract_address
    ).call()
    assert execution_result.result.address == pool.contract_address


@pytest.mark.asyncio
async def test_init_liquidity(contract_factory):
    (
        _, deployer_account, _, token_0, token_1, pool, _
    ) = contract_factory

    pool = await whitelist_pool(contract_factory)

    lp_token0_initial_balance = await token_0.balanceOf(
        deployer_account.contract_address
    ).call()
    lp_token1_initial_balance = await token_1.balanceOf(
        deployer_account.contract_address
    ).call()

    await add_liquidity(contract_factory, token_0_amount, token_1_amount, init=True)

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
    assert execution_info.result.balance == amounts_sqrt


@pytest.mark.asyncio
async def test_remove_liquidity(contract_factory):
    (
        _, deployer_account, _, token_0, token_1, pool, router
    ) = contract_factory
    deployer, _ = get_signers()

    pool = await whitelist_pool(contract_factory)

    await add_liquidity(contract_factory, token_0_amount, token_1_amount, init=True)

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
            spender, *amounts_sqrt]
    )

    await deployer.send_transaction(
        deployer_account,
        router.contract_address,
        "removeLiquidity",
        [
            token_0.contract_address,
            token_1.contract_address,
            *amounts_sqrt,
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
async def test_get_amount_in(contract_factory):
    (
        _, _, _, token_0, token_1, _, router
    ) = contract_factory

    amount_out = uint(100)
    amount_in = get_amount_in(amount_out, token_0_amount, token_1_amount)

    await whitelist_pool(contract_factory)
    await add_liquidity(contract_factory, token_0_amount, token_1_amount, init=True)

    execution_info = await router.getAmountIn(
        token_0.contract_address, token_1.contract_address, amount_out
    ).call()
    assert execution_info.result.amountIn == amount_in


@pytest.mark.asyncio
async def test_get_amount_out(contract_factory):
    (
        _, _, _, token_0, token_1, _, router
    ) = contract_factory

    amount_in = uint(100)
    amount_out = get_amount_out(amount_in, token_0_amount, token_1_amount)

    await whitelist_pool(contract_factory)
    await add_liquidity(contract_factory, token_0_amount, token_1_amount, init=True)

    execution_info = await router.getAmountOut(
        token_0.contract_address, token_1.contract_address, amount_in
    ).call()
    assert execution_info.result.amountOut == amount_out


@pytest.mark.asyncio
async def test_exact_input(contract_factory):
    (
        _, deployer_account, swapper_account, token_0, token_1, _, router
    ) = contract_factory
    deployer, swapper = get_signers()

    await whitelist_pool(contract_factory)

    await add_liquidity(contract_factory, token_0_amount, token_1_amount, init=True)

    amount_in = uint(100)
    token_in = token_0.contract_address
    token_out = token_1.contract_address
    spender = router.contract_address
    amount_out = get_amount_out(amount_in, token_0_amount, token_1_amount)
    amount_out_min = uint(80)

    # Increase swapper balance by transfering token_in from pool_creator to swapper
    await deployer.send_transaction(
        deployer_account,
        token_in,
        "transfer",
        [swapper_account.contract_address, *amount_in],
    )

    # Approve token_in
    await swapper.send_transaction(
        swapper_account, token_in, "approve", [spender, *amount_in]
    )

    # Get swapper initial balances
    execution_info = await token_0.balanceOf(swapper_account.contract_address).call()
    token_in_initial_balance = execution_info.result.balance
    execution_info = await token_1.balanceOf(swapper_account.contract_address).call()
    token_out_initial_balance = execution_info.result.balance

    # Swap token_in for token_out
    await swapper.send_transaction(
        swapper_account,
        router.contract_address,
        "exactInput",
        [token_in, token_out, *amount_in, *amount_out_min],
    )

    # Get swapper balance after swap
    execution_info = await token_0.balanceOf(swapper_account.contract_address).call()
    assert execution_info.result.balance == uint(
        token_in_initial_balance[0] - amount_in[0])
    execution_info = await token_1.balanceOf(swapper_account.contract_address).call()
    assert execution_info.result.balance == uint(
        token_out_initial_balance[0] + amount_out[0]
    )
