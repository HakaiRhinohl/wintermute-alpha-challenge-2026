#!/usr/bin/env python3
"""Show DutchX auctions scheduled shortly before the challenge fork block.

This is a read-only historical-state explorer. It does not submit transactions
and it does not choose a profitable pair.
"""

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path
from urllib.request import Request, urlopen


FORK_BLOCK = 9_462_777
DUTCHX = "0xb9812E2fA995EC53B5b6DF34d21f9304762C5497"
AUCTION_START_SCHEDULED = (
    "0x20017e7b1ef8e7882103f55ff346ca3135c4afe13dff1da2f01b482aece766a5"
)
# Shared archive RPCs commonly cap eth_getLogs ranges. Keep each request small.
MAX_BLOCK_SPAN = 1_000


def env_value(name: str) -> str:
    """Read one value from the root .env file without printing secrets."""
    for line in Path(".env").read_text(encoding="utf-8").splitlines():
        if line.startswith(name + "="):
            return line.split("=", 1)[1].strip().strip('"').strip("'")
    raise RuntimeError(f"{name} is not set in the root .env file")


def rpc(url: str, method: str, params: list) -> object:
    payload = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    request = Request(url, data=payload, headers={"Content-Type": "application/json"})
    with urlopen(request, timeout=45) as response:
        data = json.load(response)
    if "error" in data:
        raise RuntimeError(data["error"])
    return data["result"]


def address_from_topic(topic: str) -> str:
    return "0x" + topic[-40:]


def utc(timestamp: int) -> str:
    return datetime.fromtimestamp(timestamp, tz=timezone.utc).strftime("%Y-%m-%d %H:%M UTC")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--window-blocks",
        type=int,
        default=7_200,
        help="how far before the fork block to look (default: about 24 hours)",
    )
    args = parser.parse_args()
    start = FORK_BLOCK - args.window_blocks

    rpc_url = env_value("ETH_RPC_URL")
    logs = []
    for chunk_start in range(start, FORK_BLOCK + 1, MAX_BLOCK_SPAN):
        chunk_end = min(chunk_start + MAX_BLOCK_SPAN - 1, FORK_BLOCK)
        print(f"Reading blocks {chunk_start:,}–{chunk_end:,}", end="\r", flush=True)
        logs.extend(
            rpc(
                rpc_url,
                "eth_getLogs",
                [{
                    "address": DUTCHX,
                    "fromBlock": hex(chunk_start),
                    "toBlock": hex(chunk_end),
                    "topics": [AUCTION_START_SCHEDULED],
                }],
            )
        )

    print(" " * 50, end="\r")

    print(f"DutchX auctions scheduled from block {start:,} to {FORK_BLOCK:,}")
    print("Only events before the fork are shown. This is not current mainnet state.\n")

    if not logs:
        print("No AuctionStartScheduled events in this window. Increase --window-blocks.")
        return

    for log in logs:
        sell_token = address_from_topic(log["topics"][1])
        buy_token = address_from_topic(log["topics"][2])
        auction_index = int(log["topics"][3], 16)
        auction_start = int(log["data"], 16)
        print(f"Block {int(log['blockNumber'], 16):,}  auction #{auction_index}")
        print(f"  sell:  {sell_token}")
        print(f"  buy:   {buy_token}")
        print(f"  start: {utc(auction_start)}")
        print(f"  tx:    {log['transactionHash']}")
        print()


if __name__ == "__main__":
    main()
