# From First Principles: A Research Walkthrough of the Wintermute Alpha Challenge

The Wintermute Alpha Challenge is a set of investigations into how blockchain
systems behave when contracts, transaction history, market structure, and
cross-chain infrastructure meet.

The cases ask very different things of the solver: finding an address from
onchain evidence, resolving a dispute game, reconstructing a historical
auction, or reaching an L2 that does not expose a conventional bridge. What
connects them is the need to reason from first principles rather than treating
the blockchain as a black box.

This article documents the reasoning behind each solution. It is not intended
as an answer key or a collection of opaque scripts. Every case starts with the
relevant concepts, then explains how to identify the useful evidence, how to
test a hypothesis, and finally how to reproduce the solution.

The objective is not only to show what works, but to explain why it works,
which assumptions make it valid, and how the same reasoning can be applied to
a new onchain problem.

## Case 01: Out of Nowhere

### The question

The case begins with a [large USDC transfer on Ethereum](https://etherscan.io/tx/0xe7b8d46c3f3e5f727cb42c9dfe7fc36855ab5092cf160e4c8812a2a27a84350b).
Roughly $1.5 million is sent from Allbridge to an address that provides bridge
liquidity. Looking only at Ethereum, the transfer appears to come out of
nowhere. The task is to identify the transaction on the source chain that
caused it.

This is a useful first lesson in cross-chain analysis: a bridge transfer is
not usually a single transaction that moves the same tokens from one chain to
another. It is a coordinated pair of actions on separate ledgers.

```text
Source chain                                    Destination chain

user locks source asset                         bridge releases destination asset
      |                                                       |
      +---------------- bridge message / verification -------+
```

The destination transaction proves that a release happened on Ethereum. It
does not by itself identify which source-chain transaction initiated the
transfer. To do that reliably, we need the bridge's correlation data.

### Start with the receipt, not the transfer amount

The ERC-20 transfer shows Allbridge sending USDC to the recipient, but amounts
and recipients are weak search keys. The same address can bridge repeatedly,
and many transfers can have the same rounded value.

The more useful evidence is in Allbridge's `Received` event in the Ethereum
transaction receipt:

```solidity
Received(
    address recipient,
    address token,
    uint256 amount,
    uint128 lockId,
    bytes4 source
)
```

The event tells us four different things:

| Field | Value | Meaning |
| --- | --- | --- |
| `recipient` | `0xEc5f…994b` | The EVM address that received the released USDC. |
| `token` | Ethereum USDC | The asset paid on the destination chain. |
| `amount` | `1,498,500 USDC` | The net destination amount. |
| `lockId` | `0x0159fa4cd496a40b6531521bb9138a06` | The bridge transfer identifier. |
| `source` | `0x53544b5a` | The source-chain code, `STKZ`, for Stacks. |

`lockId` is the crucial field. Unlike the amount, it is assigned to this
specific bridge operation and is carried across the protocol. It turns the
problem from "find a transfer that looks similar" into "find the source call
that contains the same unique identifier".

### Interpreting the two bridge legs

The destination event says that Ethereum USDC was released. Since `source`
points to Stacks, the matching action must be a Stacks-side Allbridge call
that locked the source representation of the asset and instructed the bridge
to pay the EVM recipient on Ethereum.

It is important to search for `lock`, not `unlock`:

- `lock` is the source-side action. The user deposits or escrows the source
  asset and creates the cross-chain instruction.
- `unlock` is a release action. It belongs to the opposite leg of a bridge
  flow, not to the origin we are trying to identify.

This distinction prevents a common analytical mistake: looking for any bridge
event with a matching-looking amount instead of following the direction of the
asset flow.

### Finding the source transaction

The Allbridge Stacks contract has thousands of indexed calls. Manually
scrolling through them is possible but neither reliable nor reproducible. The
right use of a script here is narrow: page through the public contract history,
keep only `lock` calls, and compare their `lock-id` argument with the value
from Ethereum.

```bash
python3 scripts/find_stacks_lock.py 0x0159fa4cd496a40b6531521bb9138a06
```

The matching transaction is:

```text
0x36f2d5c245d08de980d0d23e4bd23b088312ce9e4b9845b4fd71930f52aab8fc
```

Its [Hiro Explorer page](https://explorer.hiro.so/txid/0x36f2d5c245d08de980d0d23e4bd23b088312ce9e4b9845b4fd71930f52aab8fc?chain=mainnet)
shows a successful call to `lock` with these relevant arguments:

```text
lock-id:     0x0159fa4cd496a40b6531521bb9138a06
amount:      1,500,000,000,000
recipient:   0xec5f2efa1a13c81179ddb0f0d4385e99e275994b + 12 zero bytes
destination: 0x45544800
```

The recipient is stored as a 32-byte buffer on Stacks. Its first 20 bytes are
the same EVM address that received USDC on Ethereum. `0x45544800` is the
ASCII encoding of `ETH` followed by padding, confirming Ethereum as the
destination.

### Verify more than one field

The `lockId` is sufficient to establish the bridge correlation, but a good
investigation checks whether the rest of the instruction makes sense too.

| Field | Stacks source `lock` | Ethereum destination `Received` | Result |
| --- | --- | --- | --- |
| `lockId` | `0x0159…8a06` | `0x0159…8a06` | Exact match |
| Recipient | 32-byte buffer beginning `0xec5f…994b` | `0xEc5f…994b` | Exact match after decoding |
| Destination | `ETH` | Ethereum | Consistent |
| Gross amount | `1,500,000 USDC` | N/A | Source instruction |
| Net amount | N/A | `1,498,500 USDC` | Destination release |

USDC has six decimals. The difference between the gross source amount and the
net Ethereum amount is therefore:

```text
1,500,000.000000
-1,498,500.000000
-----------------
    1,500.000000 USDC
```

That is a `0.1%` bridge fee. The amount reconciliation is supporting evidence,
not the primary identifier. The exact `lockId`, recipient and destination are
what make the attribution robust.

### What this case teaches

The final answer is a Stacks transaction hash, but the useful skill is broader:

1. Treat a bridge as a multi-ledger protocol, not as a single transfer.
2. Start from emitted bridge events, where protocols expose structured
   correlation data.
3. Prefer a unique operation identifier over amount or address matching.
4. Check direction: a source-side lock and a destination-side release have
   different roles.
5. Use scripts to make a targeted search reproducible, then independently
   verify the matching fields.

With the origin transaction stored in
[`challenges/01-out-of-nowhere/answer.txt`](challenges/01-out-of-nowhere/answer.txt),
the local checker returns `25/25`:

```bash
python3 alpha.py check 01
```
