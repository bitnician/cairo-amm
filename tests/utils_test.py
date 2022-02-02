import pytest
import asyncio


from utils.helper import str_to_felt


@pytest.fixture(scope="module")
def event_loop():
    return asyncio.new_event_loop()


@pytest.mark.asyncio
async def test_str_to_felt():
    usdt_felt = str_to_felt("USDT")
    eth_felt = str_to_felt("ETH")

    assert usdt_felt == 1431520340
    assert eth_felt == 4543560
