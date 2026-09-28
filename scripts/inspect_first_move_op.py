#!/usr/bin/env python3
"""Inspect the candidate first attack in Alpha Challenge case 08.

This script is deliberately read-only. It never writes ``answer.txt``: it
prints the evidence needed to decide whether a proposed bytes32 is correct.

The games in the challenge expose ``l2BlockNumber`` and ``startingBlockNumber``.
Those are the output-root FaultDisputeGame interface, not the super-root game
interface. For a root attack at gindex 2, the game first selects a theoretical
L2 block using the game-tree position. An honest challenger must then clamp
that number to the L2 *safe head at the game's L1 head*. This matters here:
the theoretical number is beyond either chain's available L2 history.

Preferred route
---------------
An op-node exposes ``optimism_safeHeadAtL1Block``. If available, it is the
authoritative way to retrieve the safe head at the retained L1 block.

EVM-only diagnostic
-------------------
Most commercial endpoints only expose the EVM API. The L1 origin recorded in
every canonical OP Stack L2 block gives an *upper bound*: the last canonical
block whose origin is no later than the retained L1 block. It is useful for
debugging, but it is not a safe-head reconstruction: a block can have an old
L1 origin and still be unsafe because its sequencing data was not yet posted
to L1. The script deliberately stops at that diagnostic rather than emitting a
claim from it.

Once either route has selected the safe head, the script rebuilds the standard
OutputRootProof V0:

    keccak256(bytes32(0) || stateRoot || messagePasserStorageRoot || blockHash)

Both routes print the intermediate block and every hash used in the final
OutputRootProof calculation, so the checker is not treated as a black box.

Usage:
    python3 scripts/inspect_first_move_op.py --chain all

Environment variables (normally stored in the untracked .env file):
    ETH_RPC_URL or L1_RPC_URL      Ethereum L1 endpoint
    INK_RPC_URL                    Ink L2 endpoint
    OP_RPC_URL                     Optimism L2 endpoint
    TATUM_API_KEY                  only sent to a Tatum gateway, if applicable

If the safe-head value has been obtained from a trusted op-node or independent
on-chain derivation, it may be supplied explicitly for one chain:
    python3 scripts/inspect_first_move_op.py --chain ink --safe-head 123456
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any
from urllib.error import HTTPError
from urllib.request import Request, urlopen


ROOT = Path(__file__).resolve().parents[1]

# Values stated in challenges/08-first-move/README.md.
L1_HEAD = "0xd74f339891bc1c4af93bf4bb55c03fc3feb62da272a1f7aa3eabb9e2410126f4"
L2_BLOCK_NUMBER = 1_787_098_259
SPLIT_DEPTH = 30
L1_BLOCK_PREDEPLOY = "0x4200000000000000000000000000000000000015"
L2_TO_L1_MESSAGE_PASSER = "0x4200000000000000000000000000000000000016"
L1_BLOCK_NUMBER_CALLDATA = "0x8381f58a"  # number()

CHAINS = {
    "ink": {"label": "Ink", "starting_block": 52_959_235, "env": "INK_RPC_URL"},
    "optimism": {
        "label": "Optimism",
        "starting_block": 155_446_493,
        "env": "OP_RPC_URL",
    },
}

# These are the official Blockscout instances listed by each chain. We use
# their batch index only to locate the L1 publication transaction; that
# transaction's L1 block number is then verified against the user's L1 RPC.
BATCH_EXPLORERS = {
    "ink": "https://explorer.inkonchain.com",
    "optimism": "https://explorer.optimism.io",
}


def env_value(name: str) -> str | None:
    """Read an environment value, then the local untracked .env file."""
    value = os.environ.get(name)
    if value:
        return value

    dotenv = ROOT / ".env"
    if not dotenv.exists():
        return None
    for raw_line in dotenv.read_text().splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, candidate = line.split("=", 1)
        if key.strip() == name:
            return candidate.strip().strip('"').strip("'")
    return None


def headers_for(url: str) -> dict[str, str]:
    """Add a gateway key only to the gateway it belongs to."""
    headers: dict[str, str] = {}
    if "gateway.tatum.io" in url:
        tatum_api_key = env_value("TATUM_API_KEY")
        if tatum_api_key:
            headers["x-api-key"] = tatum_api_key
    return headers


def rpc(url: str, method: str, params: list[Any]) -> Any:
    payload = json.dumps(
        {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}
    ).encode()
    request = Request(
        url,
        data=payload,
        headers={
            "Content-Type": "application/json",
            "User-Agent": "wintermute-alpha-research/1.0",
            **headers_for(url),
        },
    )
    try:
        with urlopen(request, timeout=45) as response:
            data = json.load(response)
    except HTTPError as error:
        body = error.read().decode(errors="replace")
        raise RuntimeError(f"HTTP {error.code}: {body}") from error
    if "error" in data:
        raise RuntimeError(json.dumps(data["error"]))
    return data["result"]


def get_json(url: str) -> Any:
    """Fetch a read-only explorer response without sending RPC credentials."""
    request = Request(url, headers={"User-Agent": "wintermute-alpha-research/1.0"})
    try:
        with urlopen(request, timeout=45) as response:
            return json.load(response)
    except HTTPError as error:
        body = error.read().decode(errors="replace")
        raise RuntimeError(f"HTTP {error.code}: {body}") from error


def as_int(value: Any) -> int:
    if isinstance(value, int):
        return value
    if isinstance(value, str):
        return int(value, 16) if value.startswith("0x") else int(value)
    raise TypeError(f"cannot turn {value!r} into an integer")


def bytes32(value: str) -> bytes:
    raw = bytes.fromhex(value.removeprefix("0x"))
    if len(raw) != 32:
        raise ValueError(f"expected a bytes32, got {value}")
    return raw


def keccak256(data: bytes) -> str:
    """Use Foundry's Ethereum Keccak implementation (not Python's SHA3)."""
    if shutil.which("cast") is None:
        raise RuntimeError("Foundry `cast` is required to calculate Keccak-256.")
    completed = subprocess.run(
        ["cast", "keccak", "0x" + data.hex()],
        check=True,
        text=True,
        capture_output=True,
    )
    return completed.stdout.strip()


def retained_l1_number(l1_rpc: str) -> int:
    header = rpc(l1_rpc, "eth_getBlockByHash", [L1_HEAD, False])
    if header is None:
        raise RuntimeError("the L1 endpoint cannot serve the retained l1Head header")
    if header["hash"].lower() != L1_HEAD:
        raise RuntimeError("L1 endpoint returned a different header for l1Head")
    return as_int(header["number"])


def origin_l1_number(l2_rpc: str, l2_block: int) -> int:
    """Return the L1 origin embedded in an OP Stack L2 block's L1Block contract."""
    raw = rpc(
        l2_rpc,
        "eth_call",
        [{"to": L1_BLOCK_PREDEPLOY, "data": L1_BLOCK_NUMBER_CALLDATA}, hex(l2_block)],
    )
    return as_int(raw)


def safe_head_from_op_node(l2_rpc: str, l1_number: int) -> int | None:
    """Use the optional rollup-node API when the endpoint exposes it."""
    try:
        response = rpc(l2_rpc, "optimism_safeHeadAtL1Block", [hex(l1_number)])
    except RuntimeError as error:
        print("op-node safe-head API unavailable:", error)
        return None

    # Current op-node response is {l1Block: {...}, safeHead: {...}}. Be
    # accepting of a directly returned block reference as a small compatibility aid.
    safe_head = response.get("safeHead", response) if isinstance(response, dict) else None
    if not isinstance(safe_head, dict) or "number" not in safe_head:
        print("op-node returned an unrecognised safe-head response:", response)
        return None
    return as_int(safe_head["number"])


def l1_origin_upper_bound(l2_rpc: str, lower: int, retained_l1: int) -> int:
    """Find the final canonical L2 block with an L1 origin <= retained_l1.

    L1 origins are monotonically non-decreasing across canonical OP Stack L2
    blocks, so this reconstruction needs logarithmically many historical
    eth_call requests.
    """
    latest = as_int(rpc(l2_rpc, "eth_blockNumber", []))
    if latest < lower:
        raise RuntimeError("L2 endpoint is behind the challenge's anchor block")

    lower_origin = origin_l1_number(l2_rpc, lower)
    if lower_origin > retained_l1:
        raise RuntimeError(
            "the provided starting block is already derived after the retained L1 head"
        )

    if origin_l1_number(l2_rpc, latest) <= retained_l1:
        return latest

    lo, hi = lower, latest
    while lo + 1 < hi:
        mid = (lo + hi) // 2
        if origin_l1_number(l2_rpc, mid) <= retained_l1:
            lo = mid
        else:
            hi = mid
    return lo


def safe_head_from_published_batches(
    chain_name: str, l1_rpc: str, l2_rpc: str, retained_l1: int
) -> int | None:
    """Find the last L2 batch published no later than ``retained_l1``.

    The L1 origin in an L2 header cannot prove L2 safety: the sequencer may
    have built a block before its batch reached L1. Blockscout indexes the
    mapping from an L2 block to its batch and the batch to its L1 publication
    transaction. We independently ask the configured L1 RPC for that
    transaction's block number, then walk backwards until it falls at or
    before the retained L1 block.

    This is a practical read-only reconstruction for this challenge. A local
    op-node with SafeDB remains the protocol-native source of truth.
    """
    try:
        origin_upper = l1_origin_upper_bound(
            l2_rpc, CHAINS[chain_name]["starting_block"], retained_l1
        )
        explorer = BATCH_EXPLORERS[chain_name]
        block = get_json(f"{explorer}/api/v2/blocks/{origin_upper}")
        optimism = block.get("optimism") if isinstance(block, dict) else None
        if not isinstance(optimism, dict) or "number" not in optimism:
            raise RuntimeError("the explorer did not attach batch metadata to the L2 block")
        batch_number = as_int(optimism["number"])
    except RuntimeError as error:
        print("batch-index safe-head reconstruction unavailable:", error)
        return None

    print("L1-origin upper-bound diagnostic", origin_upper)
    print("batch containing that diagnostic block", batch_number)

    # The batches immediately surrounding this L1 head are consecutive. Keep
    # a defensive finite bound so a malformed explorer response cannot loop.
    for candidate_batch in range(batch_number, batch_number - 128, -1):
        try:
            batch = get_json(
                f"{explorer}/api/v2/optimism/batches/{candidate_batch}"
            )
        except RuntimeError as error:
            print("could not read batch", candidate_batch, error)
            continue

        tx_hashes = batch.get("l1_transaction_hashes", []) if isinstance(batch, dict) else []
        if not isinstance(tx_hashes, list) or not tx_hashes:
            print("batch", candidate_batch, "has no L1 publication transaction")
            continue

        try:
            l1_blocks: list[int] = []
            for tx_hash in tx_hashes:
                transaction = rpc(l1_rpc, "eth_getTransactionByHash", [tx_hash])
                if transaction is None or transaction.get("blockNumber") is None:
                    raise RuntimeError(f"L1 transaction unavailable: {tx_hash}")
                l1_blocks.append(as_int(transaction["blockNumber"]))
        except RuntimeError as error:
            print("could not verify the L1 inclusion for batch", candidate_batch, error)
            return None

        # A multi-transaction batch is safe only once its final piece is in L1.
        inclusion = max(l1_blocks)
        l2_end = as_int(batch["l2_end_block_number"])
        print(
            "batch",
            candidate_batch,
            "L1 inclusion",
            inclusion,
            "L2 range",
            f"{as_int(batch['l2_start_block_number'])}-{l2_end}",
        )
        if inclusion <= retained_l1:
            return l2_end

    print("no L1-published batch found within the backwards search window")
    return None


def output_root(l2_rpc: str, l2_block: int) -> str:
    """Rebuild the V0 output root from a historical L2 header and state proof."""
    header = rpc(l2_rpc, "eth_getBlockByNumber", [hex(l2_block), False])
    if header is None:
        raise RuntimeError("L2 endpoint cannot serve the candidate safe-head header")

    state_root = header["stateRoot"]
    block_hash = header["hash"]
    header_passer_root = header.get("withdrawalsRoot")
    try:
        proof = rpc(
            l2_rpc,
            "eth_getProof",
            [L2_TO_L1_MESSAGE_PASSER, [], hex(l2_block)],
        )
        passer_root = proof["storageHash"]
        passer_source = "message passer eth_getProof storageHash"
        if header_passer_root:
            print("withdrawalsRoot in the L2 header", header_passer_root)
            print("header root equals message passer proof", header_passer_root.lower() == passer_root.lower())
    except RuntimeError as error:
        if not header_passer_root:
            raise RuntimeError(
                "could not obtain the message passer storage root: " + str(error)
            ) from error
        passer_root = header_passer_root
        passer_source = "withdrawalsRoot in the L2 header (eth_getProof unavailable)"
        print("eth_getProof unavailable; using header field:", error)

    print("L2 header timestamp", as_int(header["timestamp"]))
    print("L2 state root", state_root)
    print("message passer root source", passer_source)
    print("message passer storage root", passer_root)
    print("L2 block hash", block_hash)

    preimage = (
        b"\x00" * 32
        + bytes32(state_root)
        + bytes32(passer_root)
        + bytes32(block_hash)
    )
    return keccak256(preimage)


def output_root_from_op_node(l2_rpc: str, l2_block: int) -> str | None:
    """Ask an op-node for an output root, when its rollup API is exposed."""
    try:
        response = rpc(l2_rpc, "optimism_outputAtBlock", [hex(l2_block)])
    except RuntimeError as error:
        print("op-node output-root API unavailable:", error)
        return None

    # The documented shape is [version, outputRoot]. Some client versions
    # return an object, so accept that form too without guessing other fields.
    if isinstance(response, list) and len(response) >= 2 and isinstance(response[1], str):
        return response[1]
    if isinstance(response, dict):
        root = response.get("outputRoot")
        if isinstance(root, str):
            return root
    print("op-node returned an unrecognised output-root response:", response)
    return None


def inspect_chain(
    chain_name: str, l1_rpc: str, l2_rpc: str, supplied_safe_head: int | None
) -> None:
    chain = CHAINS[chain_name]
    l1_number = retained_l1_number(l1_rpc)

    # At gindex 2, depth=1. Its trace index at split depth 30 is 2^29 - 1;
    # adding one produces an offset of 2^29 from the starting output block.
    first_attack_offset = 1 << (SPLIT_DEPTH - 1)
    theoretical = min(chain["starting_block"] + first_attack_offset, L2_BLOCK_NUMBER)

    print(f"=== {chain['label']} case-08: first root attack ===")
    print("retained L1 head", L1_HEAD)
    print("retained L1 block number", l1_number)
    print("starting L2 block", chain["starting_block"])
    print("split depth", SPLIT_DEPTH)
    print("gindex-2 theoretical L2 block", theoretical)
    print("why it is not queried directly", "it must be clamped to the L1-derived safe head")

    safe_head = supplied_safe_head
    source = "explicit --safe-head value"
    if safe_head is None:
        safe_head = safe_head_from_op_node(l2_rpc, l1_number)
        source = "op-node optimism_safeHeadAtL1Block"
    if safe_head is None:
        safe_head = safe_head_from_published_batches(
            chain_name, l1_rpc, l2_rpc, l1_number
        )
        source = "L1 batch-publication boundary, cross-checked with L1 RPC"
    if safe_head is None:
        print("No authoritative safe head was obtained, so no claim is calculated.")
        return

    honest_block = min(theoretical, safe_head)
    print("safe-head source", source)
    print("L2 safe head", safe_head)
    print("honest block after clamp", honest_block)
    print("L1 origin at honest block", origin_l1_number(l2_rpc, honest_block))

    claim = output_root_from_op_node(l2_rpc, honest_block)
    if claim is None:
        claim = output_root(l2_rpc, honest_block)
    print()
    print("candidate claim for attack(rootClaim, 0, claim)", claim)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Derive the case-08 first root attack for Ink and/or Optimism."
    )
    parser.add_argument("--chain", choices=[*CHAINS, "all"], default="all")
    parser.add_argument("--l1-rpc", help="Override L1_RPC_URL / ETH_RPC_URL for this run.")
    parser.add_argument("--rpc", help="Override the selected chain's L2 RPC URL.")
    parser.add_argument(
        "--safe-head",
        type=int,
        help="Verified L2 safe-head height at the retained L1 head (one chain only).",
    )
    args = parser.parse_args()

    names = list(CHAINS) if args.chain == "all" else [args.chain]
    if args.rpc and len(names) != 1:
        sys.exit("--rpc can only be used with one --chain; use INK_RPC_URL and OP_RPC_URL for --chain all.")
    if args.safe_head is not None and len(names) != 1:
        sys.exit("--safe-head can only be used with one --chain.")

    l1_rpc = args.l1_rpc or env_value("L1_RPC_URL") or env_value("ETH_RPC_URL")
    if not l1_rpc:
        sys.exit("Missing L1_RPC_URL or ETH_RPC_URL.")

    l2_rpcs: dict[str, str] = {}
    for name in names:
        endpoint = args.rpc or env_value(CHAINS[name]["env"])
        if not endpoint:
            sys.exit(f"Missing {CHAINS[name]['env']}.")
        l2_rpcs[name] = endpoint

    for index, name in enumerate(names):
        if index:
            print()
        try:
            inspect_chain(name, l1_rpc, l2_rpcs[name], args.safe_head)
        except RuntimeError as error:
            print(f"{CHAINS[name]['label']} inspection failed:", error)


if __name__ == "__main__":
    main()
