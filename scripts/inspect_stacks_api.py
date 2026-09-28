#!/usr/bin/env python3
"""Inspect one page of Allbridge Classic transactions on Stacks.

This is an exploration tool, not a solver: it deliberately does not contain a
challenge lock ID and it does not select any transaction as an answer.
"""

import json
from urllib.parse import urlencode
from urllib.request import urlopen


CONTRACT = "SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.bridge"
BASE_URL = f"https://api.hiro.so/extended/v1/address/{CONTRACT}/transactions"


def get_json(url: str) -> dict:
    """Fetch JSON with only Python's standard library."""
    with urlopen(url, timeout=30) as response:
        return json.load(response)


def argument_value(transaction: dict, name: str) -> str:
    """Return Hiro's human-readable representation of a named call argument."""
    arguments = transaction["contract_call"]["function_args"]
    return next(arg["repr"] for arg in arguments if arg["name"] == name)


def main() -> None:
    # `limit=5` is intentionally small: first understand the schema, then paginate.
    url = BASE_URL + "?" + urlencode({"limit": 5, "offset": 0})
    page = get_json(url)

    print(f"Contract: {CONTRACT}")
    print(f"Transactions indexed by Hiro: {page['total']}")
    print()

    for transaction in page["results"]:
        call = transaction.get("contract_call")
        if call is None:
            continue

        line = f"{transaction['tx_id']}  {call['function_name']}"
        if call["function_name"] in {"lock", "unlock"}:
            line += f"  lock-id={argument_value(transaction, 'lock-id')}"
        print(line)


if __name__ == "__main__":
    main()
