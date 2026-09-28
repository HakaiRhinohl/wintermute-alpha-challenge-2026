#!/usr/bin/env python3
"""Discover X Layer V3 pools eligible for Uniswap protocol-fee collection.

This is intentionally not a search for USDT0 pools.  A V3 pool only starts
accruing Uniswap protocol fees after V3OpenFeeAdapter.triggerFeeUpdate() has
configured its fee protocol.  That permissionless adapter emits
FeeUpdateTriggered(caller, pool, feeValue), so its own logs are a much smaller
on-chain index of candidate pools than every PoolCreated event in the factory.

The script is read-only.  It reports the pools whose *current* protocolFees
slot is non-zero at the challenge fork; those are the pools worth passing to
adapter.collect() in the fork simulation.
"""

import json
import os
import sys
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen

RPC_ENV = "XLAYER_RPC_URL"
FORK_BLOCK = 68_413_600
ADAPTER = "0x6A88EF2e6511CAFfE2D006e260e7A5d1E7D4d7D7"

# keccak256("FeeUpdateTriggered(address,address,uint8)")
FEE_UPDATE_TRIGGERED = "0xa38b98e5166edaa11e3ca8a9decd55d5a224db2efb90ec8329d980e46857bcd1"


def env_value(name: str) -> str:
    value = os.environ.get(name)
    if value:
        return value
    for line in Path(".env").read_text().splitlines():
        if line.startswith(name + "="):
            return line.split("=", 1)[1].strip()
    raise RuntimeError(f"{name} is not set")


def rpc(url: str, method: str, params: list):
    payload = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    request = Request(url, data=payload, headers={"content-type": "application/json"})
    try:
        with urlopen(request, timeout=45) as response:
            result = json.load(response)
    except HTTPError as error:
        detail = error.read().decode("utf-8", "replace")
        raise RuntimeError(f"HTTP {error.code} while calling {method}: {detail}") from error
    if "error" in result:
        raise RuntimeError(result["error"])
    return result["result"]


def block_hex(block: int) -> str:
    return hex(block)


def deployment_block(url: str, address: str) -> int:
    """Find the first block with bytecode; takes about 26 eth_getCode reads."""
    low, high = 0, FORK_BLOCK
    while low < high:
        middle = (low + high) // 2
        code = rpc(url, "eth_getCode", [address, block_hex(middle)])
        if code == "0x":
            low = middle + 1
        else:
            high = middle
    return low


def logs(url: str, start: int, end: int) -> list:
    """Read adapter events, adapting to the provider's block-range cap."""
    found, cursor, span = [], start, 10_000
    while cursor <= end:
        stop = min(cursor + span - 1, end)
        query = {
            "address": ADAPTER,
            "fromBlock": block_hex(cursor),
            "toBlock": block_hex(stop),
            "topics": [FEE_UPDATE_TRIGGERED],
        }
        try:
            found.extend(rpc(url, "eth_getLogs", [query]))
            print(f"scanned adapter blocks {cursor:,}–{stop:,}", file=sys.stderr)
            cursor = stop + 1
        except RuntimeError as error:
            if span <= 100:
                raise
            span //= 2
            print(f"RPC reduced adapter log range to {span:,} blocks ({error})", file=sys.stderr)
    return found


def eth_call(url: str, target: str, selector: str) -> str:
    return rpc(url, "eth_call", [{"to": target, "data": selector}, block_hex(FORK_BLOCK)])


def address_from_word(word: str) -> str:
    return "0x" + word[-40:]


def main():
    url = env_value(RPC_ENV)
    deployed = deployment_block(url, ADAPTER)
    print(f"Adapter deployment block: {deployed:,}")
    print("Searching only FeeUpdateTriggered events from the official adapter…")

    latest_by_pool = {}
    for entry in logs(url, deployed, FORK_BLOCK):
        # topic[1] is caller; topic[2] is the indexed pool address.
        pool = address_from_word(entry["topics"][2]).lower()
        latest_by_pool[pool] = entry

    print(f"Pools ever fee-enabled by adapter: {len(latest_by_pool)}")
    print("\nPools with non-zero uncollected protocol fees at the fork:\n")

    useful = 0
    for pool, entry in latest_by_pool.items():
        fees = eth_call(url, pool, "0x1ad8b03b")[2:]
        fee0, fee1 = int(fees[:64], 16), int(fees[64:128], 16)
        if fee0 == 0 and fee1 == 0:
            continue

        token0 = address_from_word(eth_call(url, pool, "0x0dfe1681"))
        token1 = address_from_word(eth_call(url, pool, "0xd21220a7"))
        tier = int(eth_call(url, pool, "0xddca3f43"), 16)
        fee_value = int(entry["data"], 16)
        useful += 1
        print(f"pool {pool}")
        print(f"  token0 {token0}\n  token1 {token1}\n  fee tier {tier}")
        print(f"  adapter fee value {fee_value}")
        print(f"  protocol fee0 raw {fee0}\n  protocol fee1 raw {fee1}\n")

    print(f"Collectable pools with non-zero fees: {useful}")


if __name__ == "__main__":
    main()
