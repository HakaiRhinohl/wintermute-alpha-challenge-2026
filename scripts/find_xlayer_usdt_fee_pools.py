#!/usr/bin/env python3
"""Find X Layer Uniswap V3 pools containing USDT0 with uncollected protocol fees.

This is reconnaissance only: it makes eth_call/eth_getLogs requests and never
submits a transaction.  The fees it prints are still held by each V3 pool; a
permissionless V3OpenFeeAdapter.collect call is what moves them into TokenJar.
"""

import json
import os
import sys
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen

RPC_ENV = "XLAYER_RPC_URL"
FACTORY = "0x4B2ab38DBF28D31D467aA8993f6c2585981D6804"
USDT = "0x779Ded0c9e1022225f8E0630b35a9b54bE713736"
FORK_BLOCK = 68_413_600
POOL_CREATED = "0x783cca1c0412dd0d695e784568c96da2e9c22ff989357a2e8b1d9b2b4e6b7118"


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


def hex_block(block: int) -> str:
    return hex(block)


def call(url: str, target: str, selector: str) -> str:
    return rpc(url, "eth_call", [{"to": target, "data": selector}, hex_block(FORK_BLOCK)])


def word_address(raw: str) -> str:
    return "0x" + raw[-40:]


def deployment_block(url: str, address: str) -> int:
    """Find the first block containing bytecode with ~26 RPC reads."""
    lo, hi = 0, FORK_BLOCK
    while lo < hi:
        mid = (lo + hi) // 2
        code = rpc(url, "eth_getCode", [address, hex_block(mid)])
        if code == "0x":
            lo = mid + 1
        else:
            hi = mid
    return lo


def logs_for_topic(url: str, topic_position: int, start: int, end: int) -> list:
    """Fetch Factory PoolCreated logs, shrinking the block range if an RPC caps it."""
    # dRPC's free tier accepts at most 10,000 blocks per eth_getLogs call.
    results, cursor, span = [], start, 10_000
    usdt_topic = "0x" + "0" * 24 + USDT[2:].lower()
    while cursor <= end:
        stop = min(cursor + span - 1, end)
        topics = [POOL_CREATED, None, None]
        topics[topic_position] = usdt_topic
        query = {"address": FACTORY, "fromBlock": hex_block(cursor), "toBlock": hex_block(stop), "topics": topics}
        try:
            results.extend(rpc(url, "eth_getLogs", [query]))
            print(f"scanned blocks {cursor:,}–{stop:,}", file=sys.stderr)
            cursor = stop + 1
        except (RuntimeError, HTTPError) as error:
            if isinstance(error, HTTPError):
                # The public X Layer endpoint returns useful JSON/text here, but
                # urllib otherwise hides it behind the generic "HTTP 400".
                try:
                    detail = error.read().decode("utf-8", "replace")
                except Exception:
                    detail = "<unable to read HTTP error body>"
                error = RuntimeError(f"HTTP {error.code}: {detail}")
            if span <= 1_000:
                raise error
            span //= 2
            print(f"RPC reduced log range to {span:,} blocks", file=sys.stderr)
    return results


def main():
    url = env_value(RPC_ENV)
    factory_deployed = deployment_block(url, FACTORY)
    usdt_deployed = deployment_block(url, USDT)
    # No USDT pool can exist before both the factory and USDT0 exist.
    deployed = max(factory_deployed, usdt_deployed)
    print(f"Factory deployment block: {factory_deployed:,}")
    print(f"USDT0 deployment block: {usdt_deployed:,}")
    print(f"Scan starts at: {deployed:,}")
    print("Searching PoolCreated events where USDT0 is token0 or token1…")

    found = {}
    for position in (1, 2):
        for log in logs_for_topic(url, position, deployed, FORK_BLOCK):
            # The non-indexed `pool` address is the final ABI word in event data.
            pool = word_address(log["data"])
            found[pool.lower()] = pool

    if not found:
        print("No USDT0 pools found.")
        return

    print(f"\nUSDT0 pools found: {len(found)}")
    print("Amounts below are uncollected protocol fees at the challenge fork:\n")
    for pool in found.values():
        token0 = word_address(call(url, pool, "0x0dfe1681"))
        token1 = word_address(call(url, pool, "0xd21220a7"))
        fee = int(call(url, pool, "0xddca3f43"), 16)
        fees = call(url, pool, "0x1ad8b03b")[2:]
        fee0, fee1 = int(fees[:64], 16), int(fees[64:128], 16)
        usdt_fee = fee0 if token0.lower() == USDT.lower() else fee1
        print(f"pool {pool}")
        print(f"  token0 {token0}\n  token1 {token1}\n  fee tier {fee}")
        print(f"  USDT0 protocol fee raw {usdt_fee}")
        print(f"  USDT0 protocol fee whole {usdt_fee / 1e6:,.6f}\n")


if __name__ == "__main__":
    main()
