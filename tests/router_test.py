import os
import math
import pytest
import asyncio

from starkware.starknet.testing.starknet import Starknet
from starkware.starkware_utils.error_handling import StarkException
from starkware.starknet.definitions.error_codes import StarknetErrorCode
from utils.Signer import Signer
from utils.helper import get_amount_in, get_amount_out


pool_creator_private_key = 123456789987654321
deployer_private_key = 987654321987654321
swapper_private_key = 543215678954321567

pool_creator = Signer(pool_creator_private_key)
deployer = Signer(deployer_private_key)
swapper = Signer(swapper_private_key)


def uint(a):
    return (a, 0)


token_0_amount = uint(1000000)
token_1_amount = uint(4000000)
amounts_sqrt = uint(2000000)


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
        source=ACCOUNT_CONTRACT_FILE, constructor_calldata=[pool_creator.public_key, 0]
    )

    deployer_account = await starknet.deploy(
        source=ACCOUNT_CONTRACT_FILE, constructor_calldata=[deployer.public_key, 0]
    )

    swapper_account = await starknet.deploy(
        source=ACCOUNT_CONTRACT_FILE, constructor_calldata=[swapper.public_key, 0]
    )

    token_0 = await starknet.deploy(
        source=ERC20_CONTRACT_FILE,
        constructor_calldata=[deployer_account.contract_address, 0, 18],
    )

    token_1 = await starknet.deploy(
        source=ERC20_CONTRACT_FILE,
        constructor_calldata=[deployer_account.contract_address, 0, 18],
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


async def whitelist_pool(contract_factory):
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
        "whitelist_pool",
        [pool.contract_address],
    )

    return pool


async def add_liquidity(
    contract_factory, token_0_amount, token_1_amount, amounts_sqrt=uint(0)
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

    if amounts_sqrt == uint(0):
        # add liquidity
        await deployer.send_transaction(
            deployer_account,
            router.contract_address,
            "add_liquidity",
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
            "init_liquidity",
            [
                deployer_account.contract_address,
                token_0.contract_address,
                token_1.contract_address,
                *token_0_amount,
                *token_1_amount,
                *amounts_sqrt,
            ],
        )


@pytest.mark.asyncio
async def test_whitelist_pool(contract_factory):
    (
        starknet,
        router,
        token_0,
        token_1,
        pool_creator_account,
        deployer_account,
        swapper_account,
    ) = contract_factory

    pool = await whitelist_pool(contract_factory)

    execution_result = await router.get_pool_id(
        token_0.contract_address, token_1.contract_address
    ).call()
    assert execution_result.result.pool_contract_address == pool.contract_address

    execution_result = await router.get_pool_id(
        token_1.contract_address, token_0.contract_address
    ).call()
    assert execution_result.result.pool_contract_address == pool.contract_address

    await router.verify_pool_is_whitelisted(pool.contract_address).call()

    try:
        await router.verify_pool_is_whitelisted(123).call()
        assert False
    except StarkException as err:
        _, error = err.args
        assert error["code"] == StarknetErrorCode.TRANSACTION_FAILED


@pytest.mark.asyncio
async def test_init_liquidity(contract_factory):
    (
        starknet,
        router,
        token_0,
        token_1,
        pool_creator_account,
        deployer_account,
        swapper_account,
    ) = contract_factory

    pool = await whitelist_pool(contract_factory)

    lp_token_0_initial_balance = await token_0.balance_of(
        deployer_account.contract_address
    ).call()
    lp_token_1_initial_balance = await token_1.balance_of(
        deployer_account.contract_address
    ).call()

    await add_liquidity(contract_factory, token_0_amount, token_1_amount, amounts_sqrt)

    lp_token_0_updated_balance = await token_0.balance_of(
        deployer_account.contract_address
    ).call()
    lp_token_1_updated_balance = await token_1.balance_of(
        deployer_account.contract_address
    ).call()

    assert lp_token_0_updated_balance.result.res == uint(
        lp_token_0_initial_balance.result.res[0] - token_0_amount[0]
    )
    assert lp_token_1_updated_balance.result.res == uint(
        lp_token_1_initial_balance.result.res[0] - token_1_amount[0]
    )

    execution_info = await token_0.balance_of(pool.contract_address).call()
    assert execution_info.result.res == token_0_amount

    execution_info = await token_1.balance_of(pool.contract_address).call()
    assert execution_info.result.res == token_1_amount

    execution_info = await pool.balance_of(deployer_account.contract_address).call()
    assert execution_info.result.res == amounts_sqrt


@pytest.mark.asyncio
async def test_remove_liquidity(contract_factory):
    (
        starknet,
        router,
        token_0,
        token_1,
        pool_creator_account,
        deployer_account,
        swapper_account,
    ) = contract_factory

    pool = await whitelist_pool(contract_factory)

    await add_liquidity(contract_factory, token_0_amount, token_1_amount, amounts_sqrt)

    amount_a_min = uint(token_0_amount[0] - 100)
    amount_b_min = uint(token_1_amount[0] - 100)
    spender = router.contract_address

    lp_token_0_initial_balance = await token_0.balance_of(
        deployer_account.contract_address
    ).call()
    lp_token_1_initial_balance = await token_1.balance_of(
        deployer_account.contract_address
    ).call()

    await deployer.send_transaction(
        deployer_account, pool.contract_address, "approve", [spender, *amounts_sqrt]
    )

    await deployer.send_transaction(
        deployer_account,
        router.contract_address,
        "remove_liquidity",
        [
            token_0.contract_address,
            token_1.contract_address,
            *amounts_sqrt,
            *amount_a_min,
            *amount_b_min,
            deployer_account.contract_address,
        ],
    )

    lp_token_0_updated_balance = await token_0.balance_of(
        deployer_account.contract_address
    ).call()
    lp_token_1_updated_balance = await token_1.balance_of(
        deployer_account.contract_address
    ).call()

    execution_info = await pool.balance_of(deployer_account.contract_address).call()
    assert execution_info.result.res == uint(0)

    assert lp_token_0_updated_balance.result.res == uint(
        lp_token_0_initial_balance.result.res[0] + token_0_amount[0]
    )
    assert lp_token_1_updated_balance.result.res == uint(
        lp_token_1_initial_balance.result.res[0] + token_1_amount[0]
    )


@pytest.mark.asyncio
async def test_get_amount_in(contract_factory):
    (
        starknet,
        router,
        token_0,
        token_1,
        pool_creator_account,
        deployer_account,
        swapper_account,
    ) = contract_factory

    amount_out = uint(100)
    amount_in = get_amount_in(amount_out, token_0_amount, token_1_amount)

    pool = await whitelist_pool(contract_factory)
    await add_liquidity(contract_factory, token_0_amount, token_1_amount, amounts_sqrt)

    execution_info = await router.get_amount_in(
        token_0.contract_address, token_1.contract_address, amount_out
    ).call()
    assert execution_info.result.amount_in == amount_in


@pytest.mark.asyncio
async def test_get_amount_out(contract_factory):
    (
        starknet,
        router,
        token_0,
        token_1,
        pool_creator_account,
        deployer_account,
        swapper_account,
    ) = contract_factory

    amount_in = uint(100)
    amount_out = get_amount_out(amount_in, token_0_amount, token_1_amount)

    pool = await whitelist_pool(contract_factory)
    await add_liquidity(contract_factory, token_0_amount, token_1_amount, amounts_sqrt)

    execution_info = await router.get_amount_out(
        token_0.contract_address, token_1.contract_address, amount_in
    ).call()
    assert execution_info.result.amount_out == amount_out


@pytest.mark.asyncio
async def test_exact_input(contract_factory):
    (
        starknet,
        router,
        token_0,
        token_1,
        pool_creator_account,
        deployer_account,
        swapper_account,
    ) = contract_factory

    pool = await whitelist_pool(contract_factory)

    await add_liquidity(contract_factory, token_0_amount, token_1_amount, amounts_sqrt)

    amountIn = uint(100)
    token_in = token_0.contract_address
    token_out = token_1.contract_address
    spender = router.contract_address
    amount_out = get_amount_out(amountIn, token_0_amount, token_1_amount)
    amount_out_min = uint(80)

    # Increase swapper balance by transfering token_in from pool_creator to swapper
    await deployer.send_transaction(
        deployer_account,
        token_in,
        "transfer",
        [swapper_account.contract_address, *amountIn],
    )

    # Approve token_in
    await swapper.send_transaction(
        swapper_account, token_in, "approve", [spender, *amountIn]
    )

    # Get swapper initial balances
    execution_info = await token_0.balance_of(swapper_account.contract_address).call()
    token_in_initial_balance = execution_info.result.res
    execution_info = await token_1.balance_of(swapper_account.contract_address).call()
    token_out_initial_balance = execution_info.result.res

    # Swap token_in for token_out
    await swapper.send_transaction(
        swapper_account,
        router.contract_address,
        "exact_input",
        [token_in, token_out, *amountIn, *amount_out_min],
    )

    # Get swapper balance after swap
    execution_info = await token_0.balance_of(swapper_account.contract_address).call()
    assert execution_info.result.res == uint(token_in_initial_balance[0] - amountIn[0])
    execution_info = await token_1.balance_of(swapper_account.contract_address).call()
    assert execution_info.result.res == uint(
        token_out_initial_balance[0] + amount_out[0]
    )
