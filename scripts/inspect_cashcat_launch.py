#!/usr/bin/env python3
"""List CASHCAT Transfer events present at the Robinhood Chain fork block.

The first ERC-20 Transfer normally has `from = address(0)`. It is the mint
event, so its recipient identifies the initial holder of the token supply.
This script only performs JSON-RPC reads; it never signs or sends a tx.
"""

import json
import os
import sys
from pathlib import Path
from urllib.request import Request, urlopen


ROOT = Path(__file__).resolve().parents[1]
TOKEN = "0x020bfC650A365f8BB26819deAAbF3E21291018b4"
FORK_BLOCK = 120_000
MAX_BLOCK_RANGE = 10_000
TRANSFER_TOPIC = "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
ZERO_ADDRESS_TOPIC = "0x" + "0" * 64


def env_value(key: str) -> str:
    for line in (ROOT / ".env").read_text(encoding="utf-8").splitlines():
        if line.startswith(key + "="):
            return line.split("=", 1)[1].strip().strip('"').strip("'")
    return os.environ.get(key, "")


def rpc(url: str, method: str, params: list):
    body = json.dumps({"id": 1, "jsonrpc": "2.0", "method": method, "params": params}).encode()
    request = Request(url, data=body, headers={"content-type": "application/json"})
    with urlopen(request, timeout=30) as response:
        data = json.load(response)
    if "error" in data:
        raise RuntimeError(data["error"])
    return data["result"]


def address_from_topic(topic: str) -> str:
    return "0x" + topic[-40:]


def main():
    url = env_value("ROBINHOOD_RPC_URL")
    if not url:
        sys.exit("ROBINHOOD_RPC_URL is missing from .env")

    logs = []
    for start in range(0, FORK_BLOCK + 1, MAX_BLOCK_RANGE):
        end = min(start + MAX_BLOCK_RANGE - 1, FORK_BLOCK)
        page = rpc(
            url,
            "eth_getLogs",
            [{
                "address": TOKEN,
                "fromBlock": hex(start),
                "toBlock": hex(end),
                # `from` is indexed in ERC-20's Transfer event. Asking the
                # node to filter it avoids downloading thousands of trades.
                "topics": [TRANSFER_TOPIC, ZERO_ADDRESS_TOPIC],
            }],
        )
        logs.extend(page)

    print(f"CASHCAT mint events through block {FORK_BLOCK}: {len(logs)}")
    for log in logs:
        amount = int(log["data"], 16)
        sender = address_from_topic(log["topics"][1])
        recipient = address_from_topic(log["topics"][2])
        block = int(log["blockNumber"], 16)
        marker = "  <-- initial mint" if sender == "0x" + "0" * 40 else ""
        print(f"block {block:>6}  {sender} -> {recipient}  raw={amount}{marker}")


if __name__ == "__main__":
    main()
