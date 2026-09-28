# Out of Nowhere — tracing a cross-chain Allbridge transfer

> Status: draft

## Objective

Identify the source-chain transaction that caused the Ethereum transfer described
in Wintermute's *Out of Nowhere* case study.

## Starting point

The case provides an [Ethereum transaction](https://etherscan.io/tx/0xe7b8d46c3f3e5f727cb42c9dfe7fc36855ab5092cf160e4c8812a2a27a84350b)
which transfers approximately $1.5M of USDC to a liquidity provider.

TODO: In two or three sentences, explain why a transfer on Ethereum can have an
origin on another chain and why the transfer itself is not the answer.

## Evidence from the Ethereum receipt

The transaction emits Allbridge's `Received` event. Its fields provide the
cross-chain correlation data:

| Field | Value | Why it matters |
|---|---|---|
| Bridge | Allbridge Classic | Identifies the cross-chain protocol to investigate. |
| `lockId` | `0x0159fa4cd496a40b6531521bb9138a06` | Stable identifier linking both bridge legs. |
| `source` | `0x53544b5a` → `STKZ` | Identifies Stacks as the source chain. |
| Token | Ethereum USDC | Identifies the asset released on the destination chain. |
| Recipient | `0xEc5f2EFa1A13c81179dDb0f0d4385e99E275994b` | Must agree with the origin-side instruction. |

TODO: Explain why `lockId` is stronger evidence than matching only the amount or
recipient.

## Method: query the source-chain contract history

Allbridge's Stacks contract has 5,000+ historical calls, so manually scrolling an
explorer is neither reliable nor reproducible. The script
[`scripts/find_stacks_lock.py`](../scripts/find_stacks_lock.py) pages through the
public Hiro API and compares only `lock` calls' `lock-id` argument.

```bash
python3 scripts/find_stacks_lock.py 0x0159fa4cd496a40b6531521bb9138a06
```

TODO: Describe the difference between `lock` and `unlock`, and why this
investigation filters for `lock`.

## Verification of the matching Stacks transaction

The script returns [this Stacks transaction](https://explorer.hiro.so/txid/0x36f2d5c245d08de980d0d23e4bd23b088312ce9e4b9845b4fd71930f52aab8fc?chain=mainnet).

| Field | Stacks `lock` | Ethereum `Received` | Check |
|---|---|---|---|
| `lockId` | `0x0159fa4cd496a40b6531521bb9138a06` | Same | Exact match |
| Recipient | `0xec5f…994b`, zero-padded to 32 bytes | `0xEc5f…994b` | Same EVM address |
| Destination | `0x45544800` | Ethereum | `0x45544800` is ASCII `ETH` plus padding |
| Gross amount | `1,500,000,000,000` | — | Amount locked on Stacks |
| Net amount | — | `1,498,500,000,000` | Amount received as Ethereum USDC |

The fee is:

```text
1,500,000,000,000 - 1,498,500,000,000 = 1,500,000,000
```

With USDC's six decimals, this is a fee of 1,500 USDC, or 0.1% of the 1.5M USDC
gross transfer.

## Local challenge verification

Store the Stacks transaction hash in `challenges/01-out-of-nowhere/answer.txt`,
then run:

```bash
python3 alpha.py check 01
```

The local runner reports `25/25` when the hash is correct.

## Reproducibility notes

- Explorer pages are evidence viewers; the Python script makes the search
  repeatable.
- The legacy Allbridge signing endpoint returned an HTTP error during this
  investigation, so the final method relies only on public, indexed Stacks data.
- The transaction hash is not inferred from a fee or an address alone: the
  `lockId` supplies the direct cross-chain link.
