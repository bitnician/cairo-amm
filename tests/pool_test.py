import os
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


@pytest.fixture(scope="module")
def event_loop():
    return asyncio.new_event_loop()


@pytest.fixture(scope="module")
async def contract_factory():

    ACCOUNT_CONTRACT_FILE = os.path.join(
        os.path.dirname(__file__), "../contracts/test/Account.cairo"
    )

    ERC20_CONTRACT_FILE = os.path.join(
        os.path.dirname(__file__), "../contracts/test/ERC20.cairo"
    )

    starknet = await Starknet.empty()

    deployer_account = await starknet.deploy(
        source=ACCOUNT_CONTRACT_FILE, constructor_calldata=[deployer.public_key, 0]
    )

    swapper_account = await starknet.deploy(
        source=ACCOUNT_CONTRACT_FILE, constructor_calldata=[swapper.public_key, 0]
    )

    token0 = await starknet.deploy(
        source=ERC20_CONTRACT_FILE,
        constructor_calldata=[deployer_account.contract_address, 0, 18],
    )

    token1 = await starknet.deploy(
        source=ERC20_CONTRACT_FILE,
        constructor_calldata=[deployer_account.contract_address, 1, 18],
    )

    return starknet, deployer_account, swapper_account, token0, token1


async def deploy_pool(contract_factory):

    starknet, deployer_account, swapper_account, token0, token1 = contract_factory

    POOL_CONTRACT_FILE = os.path.join(
        os.path.dirname(__file__), "../contracts/Pool.cairo"
    )

    pool = await starknet.deploy(
        source=POOL_CONTRACT_FILE,
        constructor_calldata=[
            token0.contract_address,
            token1.contract_address,
        ],
    )
    return pool


@pytest.mark.asyncio
async def test_mint(contract_factory):
    starknet, deployer_account, swapper_account, token0, token1 = contract_factory

    pool = await deploy_pool(contract_factory)

    token_0_amount = uint(1000000000000000000)  # 1e18
    token_1_amount = uint(4000000000000000000)  # 4e18
    amounts_sqrt = uint(2000000000000000000)  # 2e18
    to = deployer_account.contract_address

    # Add liquidity
    await deployer.send_transaction(
        deployer_account,
        token0.contract_address,
        "transfer",
        [pool.contract_address, *token_0_amount],
    )
    await deployer.send_transaction(
        deployer_account,
        token1.contract_address,
        "transfer",
        [pool.contract_address, *token_1_amount],
    )

    # # mint LP token
    await deployer.send_transaction(
        deployer_account,
        pool.contract_address,
        "mint",
        [to, *amounts_sqrt, pool.contract_address],
    )

    execution_info = await pool.balance_of(to).call()
    assert execution_info.result.res == amounts_sqrt

    execution_info = await pool.get_total_supply().call()
    assert execution_info.result.res == amounts_sqrt

    execution_info = await token0.balance_of(pool.contract_address).call()
    assert execution_info.result.res == token_0_amount

    execution_info = await token1.balance_of(pool.contract_address).call()
    assert execution_info.result.res == token_1_amount


@pytest.mark.asyncio
async def test_burn(contract_factory):
    starknet, deployer_account, swapper_account, token0, token1 = contract_factory

    pool = await deploy_pool(contract_factory)

    token_0_amount = uint(3000000000000000000)  # 3e18
    token_1_amount = uint(3000000000000000000)  # 3e18
    amounts_sqrt = uint(3000000000000000000)  # 2e18
    to = deployer_account.contract_address

    # initial balance of liquidity provider
    lp_token0_initial_balance = await token0.balance_of(to).call()
    lp_token1_initial_balance = await token1.balance_of(to).call()

    # Add liquidity
    await deployer.send_transaction(
        deployer_account,
        token0.contract_address,
        "transfer",
        [pool.contract_address, *token_0_amount],
    )
    await deployer.send_transaction(
        deployer_account,
        token1.contract_address,
        "transfer",
        [pool.contract_address, *token_1_amount],
    )

    # mint LP token
    await deployer.send_transaction(
        deployer_account,
        pool.contract_address,
        "mint",
        [to, *amounts_sqrt, pool.contract_address],
    )

    # burn LP

    await deployer.send_transaction(
        deployer_account,
        pool.contract_address,
        "transfer",
        [pool.contract_address, *amounts_sqrt],
    )

    await deployer.send_transaction(
        deployer_account, pool.contract_address, "burn", [to, pool.contract_address]
    )

    execution_info = await pool.balance_of(to).call()
    assert execution_info.result.res == uint(0)

    execution_info = await pool.get_total_supply().call()
    assert execution_info.result.res == uint(0)

    execution_info = await token0.balance_of(pool.contract_address).call()
    assert execution_info.result.res == uint(0)

    execution_info = await token1.balance_of(pool.contract_address).call()
    assert execution_info.result.res == uint(0)

    lp_token0_updated_balance = await token0.balance_of(to).call()
    lp_token1_updated_balance = await token1.balance_of(to).call()

    assert lp_token0_initial_balance.result.res == lp_token0_updated_balance.result.res
    assert lp_token1_initial_balance.result.res == lp_token1_updated_balance.result.res


@pytest.mark.asyncio
async def test_swap_exact_input(contract_factory):
    starknet, deployer_account, swapper_account, token0, token1 = contract_factory

    pool = await deploy_pool(contract_factory)

    token_0_amount = uint(5000000000000000000)  # 5e18
    token_1_amount = uint(10000000000000000000)  # 10e18
    amounts_sqrt = uint(3000000000000000000)  # 3e18
    swapAmount = uint(1000000000000000000)  # 1e18
    outputAmount = get_amount_out(swapAmount, token_0_amount, token_1_amount)

    # Add liquidity
    await deployer.send_transaction(
        deployer_account,
        token0.contract_address,
        "transfer",
        [pool.contract_address, *token_0_amount],
    )
    await deployer.send_transaction(
        deployer_account,
        token1.contract_address,
        "transfer",
        [pool.contract_address, *token_1_amount],
    )

    await deployer.send_transaction(
        deployer_account,
        pool.contract_address,
        "mint",
        [deployer_account.contract_address, *amounts_sqrt, pool.contract_address],
    )

    # Send input tokens
    await deployer.send_transaction(
        deployer_account,
        token0.contract_address,
        "transfer",
        [pool.contract_address, *swapAmount],
    )

    # getting initialize token balance for swapper
    swapper_initial_balance = await token1.balance_of(
        swapper_account.contract_address
    ).call()

    # Swap
    await deployer.send_transaction(
        deployer_account,
        pool.contract_address,
        "swap",
        [
            *uint(0),
            *outputAmount,
            swapper_account.contract_address,
            pool.contract_address,
        ],
    )

    swapper_updated_balance = await token1.balance_of(
        swapper_account.contract_address
    ).call()
    assert swapper_updated_balance.result.res == uint(
        swapper_initial_balance.result.res[0] + outputAmount[0]
    )

    try:
        outputAmount = uint(outputAmount[0] + 1)
        await deployer.send_transaction(
            deployer_account,
            pool.contract_address,
            "swap",
            [
                *uint(0),
                *outputAmount,
                swapper_account.contract_address,
                pool.contract_address,
            ],
        )
        assert False
    except StarkException as err:
        _, error = err.args
        assert error["code"] == StarknetErrorCode.TRANSACTION_FAILED


@pytest.mark.asyncio
async def test_swap_exact_output(contract_factory):
    starknet, deployer_account, swapper_account, token0, token1 = contract_factory

    pool = await deploy_pool(contract_factory)

    token_0_amount = uint(5000000000000000000)  # 5e18
    token_1_amount = uint(10000000000000000000)  # 10e18
    amounts_sqrt = uint(3000000000000000000)  # 3e18
    swapAmount = uint(1000000000000000000)  # 1e18
    inputAmount = get_amount_in(swapAmount, token_0_amount, token_1_amount)

    # Add liquidity
    await deployer.send_transaction(
        deployer_account,
        token0.contract_address,
        "transfer",
        [pool.contract_address, *token_0_amount],
    )
    await deployer.send_transaction(
        deployer_account,
        token1.contract_address,
        "transfer",
        [pool.contract_address, *token_1_amount],
    )

    await deployer.send_transaction(
        deployer_account,
        pool.contract_address,
        "mint",
        [deployer_account.contract_address, *amounts_sqrt, pool.contract_address],
    )

    await deployer.send_transaction(
        deployer_account,
        token0.contract_address,
        "transfer",
        [pool.contract_address, *inputAmount],
    )

    # getting initialize token balance for swapper
    swapper_initial_balance = await token1.balance_of(
        swapper_account.contract_address
    ).call()

    # Swap
    await deployer.send_transaction(
        deployer_account,
        pool.contract_address,
        "swap",
        [
            *uint(0),
            *swapAmount,
            swapper_account.contract_address,
            pool.contract_address,
        ],
    )

    swapper_updated_balance = await token1.balance_of(
        swapper_account.contract_address
    ).call()
    assert swapper_updated_balance.result.res == uint(
        swapper_initial_balance.result.res[0] + swapAmount[0]
    )

    try:

        swapAmount = uint(swapAmount[0] + 1)
        await deployer.send_transaction(
            deployer_account,
            pool.contract_address,
            "swap",
            [
                *uint(0),
                *swapAmount,
                swapper_account.contract_address,
                pool.contract_address,
            ],
        )
        assert False
    except StarkException as err:
        _, error = err.args
        assert error["code"] == StarknetErrorCode.TRANSACTION_FAILED
