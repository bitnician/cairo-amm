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
    rap_felt = str_to_felt("RAP")
    ra_pool_token_felt = str_to_felt("RA-Pool-Token")

    assert usdt_felt == 1431520340
    assert eth_felt == 4543560
    assert rap_felt == 5390672
    assert ra_pool_token_felt == 6516880633314881834280318362990
