# X thread draft — Wintermute Alpha Challenge 2026, Case 08

## Post 1/9

Wintermute Alpha Challenge 2026, case 08: “First Move”.

Two hypothetical OP Stack Fault Dispute Games begin with the same absurd root claim: `0xdeadbeef…`.

The task is to make the first honest root attack on Ink and Optimism. The tricky part is not hashing. It is deciding *which historical L2 block L1 was actually backing*. 👇

## Post 2/9

1/ A dispute game is a binary search over a huge virtual execution trace.

`gindex 1` is the root.

`attack(rootClaim, 0, claim)` creates `gindex 2`: the left child, or first half of that trace.

With `splitDepth = 30`, that position is `2^29 = 536,870,912` steps after the starting output block.

## Post 3/9

2/ That produces theoretical L2 blocks:

Ink: `52,959,235 + 536,870,912 = 589,830,147`

OP: `155,446,493 + 536,870,912 = 692,317,405`

Those are not the blocks we can necessarily use. The tree chooses a position; L1 safety limits what an honest challenger may claim there.

## Post 4/9

3/ OP Stack has three useful notions of “exists”:

• unsafe: the sequencer produced the L2 block
• safe: L1 already contains enough batch data to derive it
• finalized: that L1 data is itself finalized

The game freezes an `l1Head`, so its challenger must use the L2 safe head known at that exact L1 boundary.

## Post 5/9

4/ A common trap: `L1 origin` is not the same as batch publication.

An L2 block can reference an old Ethereum block as its origin while the batch containing that L2 block was only published later.

So I followed:

`L2 block → batch → L1 batch-publication transaction → L1 inclusion block`

Only batches included by the retained `l1Head` count.

## Post 6/9

5/ For Optimism, the cutoff was L1 block `25,785,478`.

Batch 490771 was included in L1 block `25,785,468` and ends at L2 `155,749,670`.

The next batch was included in L1 `25,785,480`, two blocks too late.

Therefore OP safe head = `155,749,670`.

## Post 7/9

6/ Ink gave the same pattern.

Batch 46834 was included in L1 `25,785,442` and ends at L2 `53,599,386`.

Batch 46835 only arrived in L1 `25,785,509`.

Therefore Ink safe head = `53,599,386`.

In both games the safe head, not the tree's theoretical block, is the binding limit.

## Post 8/9

7/ Now the hash part.

At each selected L2 block, take the historical header and build Output Root V0:

`keccak256(bytes32(0) || stateRoot || messagePasserStorageRoot || blockHash)`

Every ingredient is 32 bytes. Change one storage slot, withdrawal message or header field and the claim changes completely.

## Post 9/9

8/ The reusable lesson:

tree position chooses the disputed trace endpoint;
the retained L1 head limits the evidence;
batch inclusion establishes L2 safety;
the historical header supplies the output-root commitment.

Do not use the current L2 head. Do not equate an L2 block's `L1 origin` with L1 publication. In a fault game, timing is part of validity.
