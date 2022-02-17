
import os

from starkware.starknet.testing.starknet import Starknet
from utils.Signer import Signer
from utils.helper import uint, str_to_felt


POOL_CREATOR_PRIVATE_KEY = 123456789987654321
DEPLOYER_PRIVATE_KEY = 987654321987654321
SWAPPER_PRIVATE_KEY = 543215678954321567

pool_creator = Signer(POOL_CREATOR_PRIVATE_KEY)
deployer = Signer(DEPLOYER_PRIVATE_KEY)
swapper = Signer(SWAPPER_PRIVATE_KEY)


def get_signers():
    return deployer, swapper


def get_contract_files():
    account_contract_file = os.path.join(
        os.path.dirname(__file__), "../contracts/test/Account.cairo"
    )

    erc20_contract_file = os.path.join(
        os.path.dirname(__file__), "../contracts/test/ERC20.cairo"
    )

    router_contract_file = os.path.join(
        os.path.dirname(__file__), "../contracts/Router.cairo"
    )

    pool_contract_file = os.path.join(
        os.path.dirname(__file__), "../contracts/Pool.cairo"
    )

    return account_contract_file, erc20_contract_file, router_contract_file, pool_contract_file


async def deploy_token(starknet, name, symbol, decimals, supply, owner):  # pylint: disable=too-many-arguments
    _, erc20_contract_file, _, _ = get_contract_files()

    token = await starknet.deploy(
        source=erc20_contract_file,
        constructor_calldata=[str_to_felt(name), str_to_felt(
            symbol), decimals, *uint(supply), owner],
    )

    return token


async def deploy_account(starknet, public_key):
    account_contract_file, _, _, _ = get_contract_files()

    account = await starknet.deploy(
        source=account_contract_file, constructor_calldata=[
            public_key, 0]
    )

    return account


async def deploy_pool(starknet, token_0, token_1):
    _, _, _, pool_contract_file = get_contract_files()

    pool = await starknet.deploy(
        source=pool_contract_file,
        constructor_calldata=[
            token_0,
            token_1,
        ],
    )
    return pool


async def deploy_router(starknet, owner):
    _, _, router_contract_file, _ = get_contract_files()

    router = await starknet.deploy(
        source=router_contract_file,
        constructor_calldata=[owner],
    )

    return router


async def router_fixture():

    starknet = await Starknet.empty()

    deployer_account = await deploy_account(starknet=starknet, public_key=deployer.public_key)

    swapper_account = await deploy_account(starknet=starknet, public_key=swapper.public_key)

    token_0 = await deploy_token(starknet=starknet, name="Token0", symbol="TOK0", decimals=18, supply=100000000000000000000000, owner=deployer_account.contract_address)

    token_1 = await deploy_token(starknet=starknet, name="Token1", symbol="TOK1", decimals=18, supply=100000000000000000000000, owner=deployer_account.contract_address)

    pool = await deploy_pool(starknet=starknet, token_0=token_0.contract_address, token_1=token_1.contract_address)

    router = await deploy_router(starknet=starknet, owner=deployer_account.contract_address)

    return starknet, deployer_account, swapper_account, token_0, token_1, pool, router


async def pool_fixture():

    starknet = await Starknet.empty()

    deployer_account = await deploy_account(starknet=starknet, public_key=deployer.public_key)

    swapper_account = await deploy_account(starknet=starknet, public_key=swapper.public_key)

    token_0 = await deploy_token(starknet=starknet, name="Token0", symbol="TOK0", decimals=18, supply=100000000000000000000000, owner=deployer_account.contract_address)

    token_1 = await deploy_token(starknet=starknet, name="Token1", symbol="TOK1", decimals=18, supply=100000000000000000000000, owner=deployer_account.contract_address)

    return starknet, deployer_account, swapper_account, token_0, token_1
