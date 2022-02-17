import asyncio
import pytest


from utils.helper import str_to_felt


@pytest.fixture(scope="module")
def event_loop():
    return asyncio.new_event_loop()


@pytest.mark.asyncio
async def test_str_to_felt():
    usdt_felt = str_to_felt("USDT")
    eth_felt = str_to_felt("ETH")
    ptok_felt = str_to_felt("PTOK")
    pool_token_felt = str_to_felt("Pool-Token")

    assert usdt_felt == 1431520340
    assert eth_felt == 4543560
    assert ptok_felt == 1347702603
    assert pool_token_felt == 379844936063829741888878
