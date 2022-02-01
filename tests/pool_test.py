import asyncio
import pytest


from utils.helper import get_amount_in, get_amount_out, uint, assert_revert
from fixture import pool_fixture, deploy_pool, get_signers


@pytest.fixture(scope="module")
def event_loop():
    return asyncio.new_event_loop()


@pytest.fixture(scope="module")
async def contract_factory():

    starknet, deployer_account, swapper_account, token_0, token_1 = await pool_fixture()

    return starknet, deployer_account, swapper_account, token_0, token_1


async def deploy_new_pool(contract_factory):

    starknet, _, _, token_0, token_1 = contract_factory

    pool = await deploy_pool(starknet=starknet, token_0=token_0.contract_address, token_1=token_1.contract_address)
    return pool


@pytest.mark.asyncio
async def test_mint(contract_factory):
    _, deployer_account, _, token_0, token_1 = contract_factory
    deployer, _ = get_signers()

    pool = await deploy_new_pool(contract_factory)

    token_0_amount = uint(5990000000000000)  # 1e18
    token_1_amount = uint(15000000)  # 4e18
    amounts_sqrt = uint(299749895746)  # 2e18
    recipient_address = deployer_account.contract_address

    # Add liquidity
    await deployer.send_transaction(
        deployer_account,
        token_0.contract_address,
        "transfer",
        [pool.contract_address, *token_0_amount],
    )
    await deployer.send_transaction(
        deployer_account,
        token_1.contract_address,
        "transfer",
        [pool.contract_address, *token_1_amount],
    )

    # # mint LP token
    await deployer.send_transaction(
        deployer_account,
        pool.contract_address,
        "mint",
        [recipient_address,  pool.contract_address],
    )

    execution_info = await pool.balanceOf(recipient_address).call()
    assert execution_info.result.balance == amounts_sqrt

    execution_info = await pool.totalSupply().call()
    assert execution_info.result.totalSupply == amounts_sqrt

    execution_info = await token_0.balanceOf(pool.contract_address).call()
    assert execution_info.result.balance == token_0_amount

    execution_info = await token_1.balanceOf(pool.contract_address).call()
    assert execution_info.result.balance == token_1_amount


@pytest.mark.asyncio
async def test_burn(contract_factory):
    _, deployer_account, _, token_0, token_1 = contract_factory
    deployer, _ = get_signers()

    pool = await deploy_new_pool(contract_factory)

    token_0_amount = uint(3000000000000000000)  # 3e18
    token_1_amount = uint(3000000000000000000)  # 3e18
    amounts_sqrt = uint(3000000000000000000)  # 2e18
    recipient_address = deployer_account.contract_address

    # initial balance of liquidity provider
    lp_token_0_initial_balance = await token_0.balanceOf(recipient_address).call()
    lp_token_1_initial_balance = await token_1.balanceOf(recipient_address).call()

    # Add liquidity
    await deployer.send_transaction(
        deployer_account,
        token_0.contract_address,
        "transfer",
        [pool.contract_address, *token_0_amount],
    )
    await deployer.send_transaction(
        deployer_account,
        token_1.contract_address,
        "transfer",
        [pool.contract_address, *token_1_amount],
    )

    # mint LP token
    await deployer.send_transaction(
        deployer_account,
        pool.contract_address,
        "mint",
        [recipient_address, pool.contract_address],
    )

    # burn LP

    await deployer.send_transaction(
        deployer_account,
        pool.contract_address,
        "transfer",
        [pool.contract_address, *amounts_sqrt],
    )

    await deployer.send_transaction(
        deployer_account, pool.contract_address, "burn", [
            recipient_address, pool.contract_address]
    )

    execution_info = await pool.balanceOf(recipient_address).call()
    assert execution_info.result.balance == uint(0)

    execution_info = await pool.totalSupply().call()
    assert execution_info.result.totalSupply == uint(0)

    execution_info = await token_0.balanceOf(pool.contract_address).call()
    assert execution_info.result.balance == uint(0)

    execution_info = await token_1.balanceOf(pool.contract_address).call()
    assert execution_info.result.balance == uint(0)

    lp_token_0_updated_balance = await token_0.balanceOf(recipient_address).call()
    lp_token_1_updated_balance = await token_1.balanceOf(recipient_address).call()

    assert lp_token_0_initial_balance.result.balance == lp_token_0_updated_balance.result.balance
    assert lp_token_1_initial_balance.result.balance == lp_token_1_updated_balance.result.balance


@pytest.mark.asyncio
async def test_swap_exact_input(contract_factory):
    _, deployer_account, swapper_account, token_0, token_1 = contract_factory
    deployer, _ = get_signers()

    pool = await deploy_new_pool(contract_factory)

    token_0_amount = uint(5000000000000000000)  # 5e18
    token_1_amount = uint(10000000000000000000)  # 10e18
    swap_amount = uint(1000000000000000000)  # 1e18
    output_amount = get_amount_out(swap_amount, token_0_amount, token_1_amount)

    # Add liquidity
    await deployer.send_transaction(
        deployer_account,
        token_0.contract_address,
        "transfer",
        [pool.contract_address, *token_0_amount],
    )
    await deployer.send_transaction(
        deployer_account,
        token_1.contract_address,
        "transfer",
        [pool.contract_address, *token_1_amount],
    )

    await deployer.send_transaction(
        deployer_account,
        pool.contract_address,
        "mint",
        [deployer_account.contract_address, pool.contract_address],
    )

    # Send input tokens
    await deployer.send_transaction(
        deployer_account,
        token_0.contract_address,
        "transfer",
        [pool.contract_address, *swap_amount],
    )

    # getting initialize token balance for swapper
    swapper_initial_balance = await token_1.balanceOf(
        swapper_account.contract_address
    ).call()

    # Swap
    await deployer.send_transaction(
        deployer_account,
        pool.contract_address,
        "swap",
        [
            *uint(0),
            *output_amount,
            swapper_account.contract_address,
            pool.contract_address,
        ],
    )

    swapper_updated_balance = await token_1.balanceOf(
        swapper_account.contract_address
    ).call()
    assert swapper_updated_balance.result.balance == uint(
        swapper_initial_balance.result.balance[0] + output_amount[0]
    )

    output_amount = uint(output_amount[0] + 1)
    assert_revert(deployer.send_transaction(
        deployer_account,
        pool.contract_address,
        "swap",
        [
            *uint(0),
            *output_amount,
            swapper_account.contract_address,
            pool.contract_address,
        ],
    ))


@pytest.mark.asyncio
async def test_swap_exact_output(contract_factory):
    _, deployer_account, swapper_account, token_0, token_1 = contract_factory
    deployer, _ = get_signers()

    pool = await deploy_new_pool(contract_factory)

    token_0_amount = uint(5000000000000000000)  # 5e18
    token_1_amount = uint(10000000000000000000)  # 10e18
    swap_amount = uint(1000000000000000000)  # 1e18
    input_amount = get_amount_in(swap_amount, token_0_amount, token_1_amount)

    # Add liquidity
    await deployer.send_transaction(
        deployer_account,
        token_0.contract_address,
        "transfer",
        [pool.contract_address, *token_0_amount],
    )
    await deployer.send_transaction(
        deployer_account,
        token_1.contract_address,
        "transfer",
        [pool.contract_address, *token_1_amount],
    )

    await deployer.send_transaction(
        deployer_account,
        pool.contract_address,
        "mint",
        [deployer_account.contract_address, pool.contract_address],
    )

    await deployer.send_transaction(
        deployer_account,
        token_0.contract_address,
        "transfer",
        [pool.contract_address, *input_amount],
    )

    # getting initialize token balance for swapper
    swapper_initial_balance = await token_1.balanceOf(
        swapper_account.contract_address
    ).call()

    # Swap
    await deployer.send_transaction(
        deployer_account,
        pool.contract_address,
        "swap",
        [
            *uint(0),
            *swap_amount,
            swapper_account.contract_address,
            pool.contract_address,
        ],
    )

    swapper_updated_balance = await token_1.balanceOf(
        swapper_account.contract_address
    ).call()
    assert swapper_updated_balance.result.balance == uint(
        swapper_initial_balance.result.balance[0] + swap_amount[0]
    )

    swap_amount = uint(swap_amount[0] + 1)
    assert_revert(deployer.send_transaction(
        deployer_account,
        pool.contract_address,
        "swap",
        [
            *uint(0),
            *swap_amount,
            swapper_account.contract_address,
            pool.contract_address,
        ],
    ))
