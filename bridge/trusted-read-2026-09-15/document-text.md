# Wintermute Alpha Challenge

- Document ID: 1B_Am3ONG2grNgLWqwwTLyt_6eTFQGXb1SK-SwLJEVFg
- Revision ID: ANLCKQlOIoWKeeF2QCVSC5rTjKyGhWV10mcBEK12hS8WEiuIuIKGrfIpU8xUJZnbt1qAE2u0RkFhhqyq89sTPAvz6-GvajCIWVyBi862vex0
- Selected tab: all
- Protected controls: 0
- Opaque controls: 0
- Authoritative dropdowns: 0

Protected-control annotations are preservation instructions. Do not insert their displayed placeholder text to recreate a native control.

## Tab 1 (t.0)

[P00001 | 1:186 | NORMAL_TEXT]
The Wintermute Alpha Challenge is a set of investigations into how blockchain systems behave when contracts, transaction history, market structure, and cross-chain infrastructure meet.

[P00002 | 186:519 | NORMAL_TEXT]
The cases ask very different things of the solver: finding an address from onchain evidence, resolving a dispute game, reconstructing a historical auction, or reaching an L2 that does not expose a conventional bridge. What connects them is the need to reason from first principles rather than treating the blockchain as a black box.

[P00003 | 519:815 | NORMAL_TEXT]
This article documents the reasoning behind each solution. It is not intended as an answer key or a collection of opaque scripts. Every case starts with the relevant concepts, then explains how to identify the useful evidence, how to test a hypothesis, and finally how to reproduce the solution.

[P00004 | 815:991 | NORMAL_TEXT]
The objective is not only to show what works, but to explain why it works, which assumptions make it valid, and how the same reasoning can be applied to a new onchain problem.

[P00005 | 991:1018 | HEADING_2]
## Case 01: Out of Nowhere

[P00006 | 1018:1311 | NORMAL_TEXT]
The case begins with a large [USDC transfer](https://etherscan.io/tx/0xe7b8d46c3f3e5f727cb42c9dfe7fc36855ab5092cf160e4c8812a2a27a84350b) on Ethereum. Roughly $1.5 million is sent from Allbridge to an address that provides bridge liquidity. Looking only at Ethereum, the transfer appears to come out of nowhere. The task is to identify the transaction on the source chain that caused it.

[P00007 | 1311:1312 | NORMAL_TEXT]
⟦EMPTY PARAGRAPH⟧

[P00008 | 1312:1418 | NORMAL_TEXT]
A useful first lesson is that a bridge transfer is a coordinated pair of actions on separate blockchains.

[P00009 | 1418:1419 | NORMAL_TEXT]
⟦EMPTY PARAGRAPH⟧

[P00010 | 1419:1421 | NORMAL_TEXT]
[INLINE_OBJECT kix.h7bke2rjx1em]

[P00011 | 1421:1422 | NORMAL_TEXT]
⟦EMPTY PARAGRAPH⟧

[P00012 | 1422:1621 | NORMAL_TEXT]
The destination transaction proves that a release happened on Ethereum but it does not identify which source-chain initiated the transfer. To do that reliably, we need the bridge's correlation data.

[P00013 | 1621:1926 | NORMAL_TEXT]
The ERC-20 transfer shows Allbridge sending USDC to the recipient, but amounts and recipients are weak search keys. The same address can bridge repeatedly, and many transfers can have the same rounded value. The more useful evidence is in Allbridge's `Received` event in the Ethereum transaction receipt:

[P00014 | 1926:1928 | NORMAL_TEXT]
[INLINE_OBJECT kix.abpyz2kdgcrt]

[P00015 | 1928:1970 | NORMAL_TEXT]
The event tells us four different things:

[P00016 | 1973:1979 | NORMAL_TEXT | TABLE row=0 col=0]
Field

[P00017 | 1980:1986 | NORMAL_TEXT | TABLE row=0 col=1]
Value

[P00018 | 1987:1995 | NORMAL_TEXT | TABLE row=0 col=2]
Meaning

[P00019 | 1997:2007 | NORMAL_TEXT | TABLE row=1 col=0]
recipient

[P00020 | 2008:2020 | NORMAL_TEXT | TABLE row=1 col=1]
0xEc5f…994b

[P00021 | 2021:2070 | NORMAL_TEXT | TABLE row=1 col=2]
The EVM address that received the released USDC.

[P00022 | 2072:2078 | NORMAL_TEXT | TABLE row=2 col=0]
token

[P00023 | 2079:2084 | NORMAL_TEXT | TABLE row=2 col=1]
USDC

[P00024 | 2085:2096 | NORMAL_TEXT | TABLE row=2 col=2]
Asset paid

[P00025 | 2098:2105 | NORMAL_TEXT | TABLE row=3 col=0]
amount

[P00026 | 2106:2121 | NORMAL_TEXT | TABLE row=3 col=1]
1,498,500 USDC

[P00027 | 2122:2138 | NORMAL_TEXT | TABLE row=3 col=2]
Amount recieved

[P00028 | 2140:2147 | NORMAL_TEXT | TABLE row=4 col=0]
lockid

[P00029 | 2148:2183 | NORMAL_TEXT | TABLE row=4 col=1]
0x0159fa4cd496a40b6531521bb9138a06

[P00030 | 2184:2216 | NORMAL_TEXT | TABLE row=4 col=2]
The bridge transfer identifier.

[P00031 | 2218:2225 | NORMAL_TEXT | TABLE row=5 col=0]
source

[P00032 | 2226:2237 | NORMAL_TEXT | TABLE row=5 col=1]
0x53544b5a

[P00033 | 2238:2310 | NORMAL_TEXT | TABLE row=5 col=2]
The source-chain code, `STKZ`, for Stacks (you have to decode 53544b5a)

[P00034 | 2311:2718 | NORMAL_TEXT]
With lockid and the source chain now we have to find the Allbridge contract on Stacks that matches this same lockid. We can find the Allbridge Stacks contact [here](https://docs.allbridge.io/allbridge-overview/bridge-contracts), now that we know the source chain and the contact that initiated the transaction we can use the API of [hiro](https://explorer.hiro.so/txid/0x59743b04043e82a9057686e99e8f7503adf78013b68d46e6eb32641450594d62?chain=mainnet&tab=transactions) (Stacks explorer) to find a transaction with the same lockid that the transaction we had in mainnet to find the [following transaction](https://explorer.hiro.so/txid/0x36f2d5c245d08de980d0d23e4bd23b088312ce9e4b9845b4fd71930f52aab8fc?chain=mainnet&tab=overview).

[P00035 | 2718:2720 | NORMAL_TEXT]
[INLINE_OBJECT kix.8zi6hopulrvs]

[P00036 | 2720:2783 | NORMAL_TEXT]
It was initiated by [SP388WPTVQMET2Z7M3ANQ6VRR8AATBF8VDPH0RRF9](http://SP388WPTVQMET2Z7M3ANQ6VRR8AATBF8VDPH0RRF9).

[P00037 | 2783:2784 | NORMAL_TEXT]
⟦EMPTY PARAGRAPH⟧

