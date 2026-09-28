# First Move — deriving a valid first Fault Dispute Game attack

> Status: solved. `python3 alpha.py check 08` returns `150/150`.

## Objective

The challenge presents two *hypothetical* Fault Dispute Games created on
Ethereum: one for Ink and one for Optimism. Both start from the intentionally
false root claim `0xdeadbeef…deadbeef`.

The task is to provide the honest claim for the first root attack:

```solidity
attack(rootClaim, 0, claim)
```

This is not a transaction hash and it is not the current L2 state root. It is
an OP Stack Output Root V0 for the L2 block selected by the game position and
by the L1 safety boundary frozen in the game.

## 1. The first attack selects a position, not an arbitrary L2 block

The dispute game represents a large execution/output trace as a binary tree.
The root is generalized index (`gindex`) `1`; its left child is `2` and its
right child is `3`.

```text
                 gindex 1: root
                  whole trace
                       |
             +---------+---------+
             |                   |
      gindex 2: left        gindex 3: right
       first half             second half
```

`attack(rootClaim, 0, claim)` creates the left child, i.e. `gindex = 2`.
For a split depth `D`, that position ends after half of the virtual trace:

```text
offset = 2^(D - 1)
```

The extra `+1` in the implementation arises because `startingBlockNumber` is
the output *before* the first step. In a tiny example with a start at block
`100` and `D = 4`, the left-half endpoint is `100 + 2^3 = 108`.

For this challenge, `D = 30`:

```text
2^(30 - 1) = 536,870,912
```

| Chain | Starting block | First-attack theoretical block |
| --- | ---: | ---: |
| Ink | 52,959,235 | 589,830,147 |
| Optimism | 155,446,493 | 692,317,405 |

The game computes that theoretical position mechanically. It does **not**
mean that either chain had reached that L2 block, or that L1 already backed it.

## 2. Why the L1 head is the real limit

The game stores this L1 head:

```text
0xd74f339891bc1c4af93bf4bb55c03fc3feb62da272a1f7aa3eabb9e2410126f4
```

It is Ethereum L1 block `25,785,478`. The hypothetical game creation happens
in the next L1 block, `25,785,479`, but that does not extend the evidence the
game is allowed to use. The stored `l1Head` is the fixed historical boundary.

An OP Stack sequencer can create an L2 block before the batch containing its
transaction data is posted to L1. Such a block may be visible in an explorer,
but it is **unsafe**: another node cannot yet derive it from the retained L1
chain. The honest claim must therefore use:

```text
honest block = min(theoretical block, l2BlockNumber, safe head at l1Head)
```

This is why using today's L2 head, or simply using the newest historical L2
block with an old `L1 origin`, is incorrect. `L1 origin` tells us which L1
block the sequencer used as context; it does not tell us when the L2 batch was
published to Ethereum.

The OP Stack derivation specification distinguishes unsafe blocks from blocks
derived from L1 data in exactly this way. [Derivation specification](https://specs.optimism.io/protocol/derivation.html)

## 3. Reconstructing the safe heads from L1 batch publication

An archive `op-node` with SafeDB can answer
`optimism_safeHeadAtL1Block` directly. Public EVM RPCs commonly do not expose
that rollup-specific API, so the reproducible fallback is:

```text
L2 diagnostic block
  -> indexed L2 batch
  -> L1 transaction that published the batch
  -> compare its Ethereum block number to the game's l1Head
```

The decisive question for each batch is:

```text
Was its L1 publication transaction included at or before L1 block 25,785,478?
```

### Optimism

| Batch | L1 inclusion block | L2 range | Eligible? |
| ---: | ---: | --- | --- |
| 490773 | 25,785,492 | 155,749,737–155,749,808 | No |
| 490772 | 25,785,480 | 155,749,671–155,749,736 | No |
| 490771 | 25,785,468 | 155,749,598–155,749,670 | Yes |

Thus the Optimism safe head at the retained L1 boundary is block
`155,749,670`.

### Ink

| Batch | L1 inclusion block | L2 range | Eligible? |
| ---: | ---: | --- | --- |
| 46835 | 25,785,509 | 53,599,387–53,600,178 | No |
| 46834 | 25,785,442 | 53,598,599–53,599,386 | Yes |

Thus the Ink safe head is block `53,599,386`.

Both safe heads are far below the first-attack theoretical block, so the safe
head is the binding limit in both cases.

## 4. Rebuilding the output root

At the selected historical L2 block, fetch the block header. Output Root V0
is constructed from four fixed-width values:

```text
outputRoot = keccak256(
    bytes32(0)
    || stateRoot
    || messagePasserStorageRoot
    || blockHash
)
```

Each input is 32 bytes, so the Keccak preimage is exactly 128 bytes.

- `stateRoot` commits to the complete EVM state after the block.
- `messagePasserStorageRoot` commits to L2-to-L1 withdrawal messages.
- `blockHash` fixes the exact L2 block.
- `bytes32(0)` identifies Output Root V0.

For these post-Isthmus headers, `withdrawalsRoot` is the header commitment
used as the MessagePasser storage root. The `op-node` implementation documents
this behaviour in `OutputV0AtBlock`. [Source](https://github.com/ethereum-optimism/optimism/blob/develop/op-node/node/api.go)

The resulting claims are:

```text
ink_claim = 0x82c941153a9de14c4533b301799ee33206b6a475d7c4fdbe7cd2f1c9d7271b6f
op_claim  = 0x192f163548d61d555a282e1ffcec8ec7b1e4cf9deced7e910b87292f0aeab5f1
```

## Reproduce it

[`scripts/inspect_first_move_op.py`](../scripts/inspect_first_move_op.py)
first tries the native op-node safe-head API. If unavailable, it walks the
batch-publication boundary described above and cross-checks every batch
transaction's inclusion block through the configured L1 RPC.

```bash
python3 scripts/inspect_first_move_op.py --chain all
python3 alpha.py check 08
```

## Takeaways

- A visible L2 block is not automatically an L1-backed block.
- `L1 origin` and batch-inclusion time answer different questions.
- A dispute game freezes its evidence set at `l1Head`; do not use later L1 or
  L2 data.
- The tree position determines the requested trace endpoint; it does not let
  a challenger bypass the safe-head bound.
- Claims are assertions backed by bonds, so a false root can be posted. The
  dispute protocol exists to make the correct commitment win without requiring
  L1 to execute the entire L2 state transition at game creation.
