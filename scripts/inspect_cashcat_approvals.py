#!/usr/bin/env python3
"""Find CASHCAT approvals made by its initial holder before the fork block."""

import importlib.util
from pathlib import Path


SCRIPT = Path(__file__).with_name("inspect_cashcat_launch.py")
spec = importlib.util.spec_from_file_location("cashcat_rpc", SCRIPT)
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(module)

APPROVAL_TOPIC = "0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925"
INITIAL_HOLDER = "0xd9ec2db5f3d1b236843925949fe5bd8a3836fccb"


def topic_for(address: str) -> str:
    return "0x" + "0" * 24 + address.removeprefix("0x").lower()


def main():
    url = module.env_value("ROBINHOOD_RPC_URL")
    if not url:
        raise SystemExit("ROBINHOOD_RPC_URL is missing from .env")

    logs = []
    for start in range(0, module.FORK_BLOCK + 1, module.MAX_BLOCK_RANGE):
        end = min(start + module.MAX_BLOCK_RANGE - 1, module.FORK_BLOCK)
        logs.extend(module.rpc(url, "eth_getLogs", [{
            "address": module.TOKEN,
            "fromBlock": hex(start),
            "toBlock": hex(end),
            "topics": [APPROVAL_TOPIC, topic_for(INITIAL_HOLDER)],
        }]))

    print(f"CASHCAT approvals by {INITIAL_HOLDER} through block {module.FORK_BLOCK}: {len(logs)}")
    for log in logs:
        spender = module.address_from_topic(log["topics"][2])
        amount = int(log["data"], 16)
        block = int(log["blockNumber"], 16)
        print(f"block {block:>6}  spender={spender}  allowance raw={amount}")


if __name__ == "__main__":
    main()
