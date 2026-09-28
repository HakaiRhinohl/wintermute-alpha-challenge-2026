#!/usr/bin/env python3
"""Find Stacks Allbridge `lock` calls by their bridge lock ID.

The script is intentionally generic: supply the lock ID as an argument, inspect
the returned transaction yourself, and use the explorer to verify its other
fields before treating it as an answer to any investigation.
"""

import argparse
import json
import time
from urllib.error import HTTPError
from urllib.parse import urlencode
from urllib.request import urlopen


CONTRACT = "SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.bridge"
BASE_URL = f"https://api.hiro.so/extended/v1/address/{CONTRACT}/transactions"
# Hiro's public endpoint caps this particular address endpoint at 50 records.
PAGE_SIZE = 50


def get_json(url: str) -> dict:
    try:
        with urlopen(url, timeout=30) as response:
            return json.load(response)
    except HTTPError as error:
        body = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Hiro API returned HTTP {error.code}: {body}") from error


def normalise_lock_id(value: str) -> str:
    """Make user input and Hiro's hexadecimal `repr` comparable."""
    return "0x" + value.lower().removeprefix("0x").lstrip("0")


def argument_value(transaction: dict, name: str) -> str:
    arguments = transaction["contract_call"]["function_args"]
    return next(arg["repr"] for arg in arguments if arg["name"] == name)


def page(offset: int) -> dict:
    query = urlencode({"limit": PAGE_SIZE, "offset": offset})
    return get_json(BASE_URL + "?" + query)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("lock_id", help="16-byte lock ID, in hexadecimal")
    args = parser.parse_args()
    wanted = normalise_lock_id(args.lock_id)

    first_page = page(0)
    total = first_page["total"]
    pages = (total + PAGE_SIZE - 1) // PAGE_SIZE
    print(f"Searching {total} contract transactions ({pages} pages) for {wanted}")

    for page_number, offset in enumerate(range(0, total, PAGE_SIZE), start=1):
        current_page = first_page if offset == 0 else page(offset)
        print(f"Page {page_number}/{pages}", end="\r", flush=True)

        for transaction in current_page["results"]:
            call = transaction.get("contract_call")
            if call is None or call["function_name"] != "lock":
                continue

            observed = normalise_lock_id(argument_value(transaction, "lock-id"))
            if observed == wanted:
                print("\n\nMatch found. Verify this transaction in Hiro before using it:")
                print(f"tx_id: {transaction['tx_id']}")
                print(f"function: {call['function_name']}")
                print(f"lock-id: {argument_value(transaction, 'lock-id')}")
                print("arguments:")
                for argument in call["function_args"]:
                    print(f"  {argument['name']}: {argument['repr']}")
                return

        # Be courteous to the public API while paging through its history.
        time.sleep(0.1)

    print("\nNo matching lock was found in the indexed contract history.")


if __name__ == "__main__":
    main()
