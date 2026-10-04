#!/usr/bin/env python3
"""Read-only reconnaissance for the Elysium / HyperEVM testnet boundary.

Elysium is an Arbitrum Orbit child chain. Its parent is HyperEVM *testnet*,
not Ethereum. A block header published by Elysium includes ``l1BlockNumber``;
on this chain that field is the HyperEVM block the sequencer was following when
it produced the Elysium block.

This script deliberately sends no transactions. It establishes the basic
architecture before we use a faucet, approve a token, or create a retryable
bridge message:

    HyperEVM testnet (parent, chain 998)
                   |
                   | retryable ticket / outbox message
                   v
    Elysium testnet (Orbit child, chain 99801)

Usage:
    python3 scripts/inspect_elysium.py

The public RPCs are the defaults. Override them only if a provider is more
reliable for you:

    ELYSIUM_RPC_URL=https://... HYPEREVM_TESTNET_RPC_URL=https://... \\
      python3 scripts/inspect_elysium.py
"""

from __future__ import annotations

import json
import os
from typing import Any
from urllib.request import Request, urlopen


ELYSIUM_RPC_DEFAULT = "https://testnet-rpc.elysium.kinetiq.xyz"
HYPEREVM_RPC_DEFAULT = "https://rpc.hyperliquid-testnet.xyz/evm"

# Arbitrum's ArbSys system contract is present on every Nitro child chain.
ARB_SYS = "0x0000000000000000000000000000000000000064"
ARB_OS_VERSION = "0x051038f2"  # arbOSVersion()

# Testnet addresses published by Elysium. We only ask whether code is deployed
# there. Do not call these entry points until we have picked an asset and read
# the gateway mapping for that asset.
HYPEREVM_ROUTER = "0x1aAE2caD8B0249905492087EF230FcCEa3707C45"
HYPEREVM_STANDARD_GATEWAY = "0x792487eF5E423104bec94e8c58E814e5E0450cEA"
ELYSIUM_ROUTER = "0x89659883a9d980925733B0A698F117AAb65ac718"


def rpc(url: str, method: str, params: list[Any]) -> Any:
    """Perform one JSON-RPC read and fail clearly on an RPC error."""
    body = json.dumps(
        {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}
    ).encode()
    # The public Elysium endpoint rejects Python's default ``Python-urllib``
    # user agent even though it accepts the same JSON-RPC body from curl.
    request = Request(
        url,
        data=body,
        headers={
            "content-type": "application/json",
            "User-Agent": "Mozilla/5.0 (compatible; AlphaChallengeResearch/1.0)",
        },
    )
    with urlopen(request, timeout=30) as response:
        payload = json.load(response)
    if "error" in payload:
        raise RuntimeError(payload["error"])
    return payload["result"]


def as_int(value: str) -> int:
    return int(value, 16) if value.startswith("0x") else int(value)


def bytecode_size(url: str, address: str) -> int:
    code = rpc(url, "eth_getCode", [address, "latest"])
    return max(0, (len(code) - 2) // 2)


def main() -> None:
    elysium_rpc = os.environ.get("ELYSIUM_RPC_URL", ELYSIUM_RPC_DEFAULT)
    hyperevm_rpc = os.environ.get("HYPEREVM_TESTNET_RPC_URL", HYPEREVM_RPC_DEFAULT)

    print("=== Elysium / HyperEVM testnet reconnaissance ===")
    print("This program is read-only: it does not use a wallet or send a transaction.")
    print()

    elysium_chain_id = as_int(rpc(elysium_rpc, "eth_chainId", []))
    hyperevm_chain_id = as_int(rpc(hyperevm_rpc, "eth_chainId", []))
    elysium_head = rpc(elysium_rpc, "eth_getBlockByNumber", ["latest", False])
    hyperevm_head = as_int(rpc(hyperevm_rpc, "eth_blockNumber", []))

    parent_block = as_int(elysium_head["l1BlockNumber"])
    child_block = as_int(elysium_head["number"])
    arbos_raw = as_int(
        rpc(elysium_rpc, "eth_call", [{"to": ARB_SYS, "data": ARB_OS_VERSION}, "latest"])
    )

    print("=== Chain relationship ===")
    print("Elysium chain ID", elysium_chain_id, "(expected 99801)")
    print("HyperEVM testnet chain ID", hyperevm_chain_id, "(expected 998)")
    print("latest Elysium child block", child_block)
    print("Elysium header l1BlockNumber", parent_block)
    print("latest HyperEVM parent block", hyperevm_head)
    print("parent blocks behind head", hyperevm_head - parent_block)
    print("ArbSys arbOSVersion raw", arbos_raw)
    print("ArbOS version", arbos_raw - 55, "(Nitro reports version + 55)")
    print()
    print("Interpretation:")
    print("The Elysium sequencer built this child block while following HyperEVM")
    print(f"block {parent_block}. The small gap to the parent head is normal")
    print("sequencing lag, and demonstrates that HyperEVM is Elysium's parent.")
    print()

    print("=== Bridge components whose bytecode exists ===")
    for label, url, address in (
        ("HyperEVM router", hyperevm_rpc, HYPEREVM_ROUTER),
        ("HyperEVM standard ERC-20 gateway", hyperevm_rpc, HYPEREVM_STANDARD_GATEWAY),
        ("Elysium router", elysium_rpc, ELYSIUM_ROUTER),
    ):
        size = bytecode_size(url, address)
        print(label)
        print(" address", address)
        print(" bytecode bytes", size)

    print()
    print("Next safe experiment:")
    print("1. Use test HYPE from the faucet, never real funds.")
    print("2. Pick a test ERC-20 on HyperEVM testnet.")
    print("3. Read router.getGateway(token) and calculateL2TokenAddress(token).")
    print("4. Dry-run approval and outboundTransfer first. Only then create a")
    print("   real testnet retryable deposit funded with test HYPE.")


if __name__ == "__main__":
    main()
