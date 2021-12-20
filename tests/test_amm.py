import pytest
import asyncio
from starkware.starknet.testing.starknet import Starknet


@pytest.fixture(scope='module')
def event_loop():
    return asyncio.new_event_loop()

@pytest.fixture(scope='module')
async def deployed_amm():
    starknet = await Starknet.empty()
    amm = await starknet.deploy(
        "contracts/amm.cairo",
        constructor_calldata=[]
    )
    return starknet, amm

@pytest.mark.asyncio
async def test_init_pool(deployed_amm):
    _, amm = deployed_amm
    new_owner = 123
    await amm.init_pool(token_a=10, token_b=11).invoke()
    executed_info = await amm.get_pool_token_balance(token_type=1).call()
    assert executed_info.result == (10,)
    executed_info = await amm.get_pool_token_balance(token_type=2).call()
    assert executed_info.result == (11,)