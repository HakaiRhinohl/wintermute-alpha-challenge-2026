# X thread draft — Wintermute Alpha Challenge 2026, Case 02

## Post 1/8

Wintermute Alpha Challenge 2026, case 02: “Falling Dutchman” (100 pts).

At Ethereum block 9,462,777, turn 0.1 ETH into at least 4 ETH.

The edge was not a flash loan. It was a stale Dutch auction priced ~43x below its previous close. 👇

## Post 2/8

1/ First rule: pin the historical block. Today’s DutchX page is irrelevant.

Ask an archive RPC for `AuctionStartScheduled` events shortly before block `9,462,777`. Split `eth_getLogs` into small ranges: public RPCs often reject large historical queries.

## Post 3/8

2/ The event finds auction #1051:

- sell: WETH
- buy: KNC
- start: 10 Feb 2020

That means buyers pay KNC to receive WETH. An event gives a candidate, not proof of an opportunity: now read DutchX state at the target block.

## Post 4/8

3/ Ask the contract for `getCurrentAuctionPrice(WETH, KNC, 1051)`.

It returns a fraction, not a formatted price:

`17033467344264227443149225 / 1172190779636348006673750 = 14.5313 KNC/WETH`

Both tokens use 18 decimals, so they cancel.

## Post 5/8

4/ Compare it with the previous auction close:

`5823407639064693142957 / 9253528949171880850 = 629.3175 KNC/WETH`

`629.3175 / 14.5313 = 43.3077`

DutchX was offering WETH ~43.3x cheaper than its prior close. It still had 4.482 WETH for sale.

## Post 6/8

5/ We start with ETH, but DutchX wants KNC. Query Uniswap V1 at the *same fork block*:

`0.1 ETH → 62.865191752838287641 KNC`

After DutchX’s maximum 0.5% buyer fee:

`62.865 × 0.995 / 14.531 ≈ 4.304 WETH`

The arithmetic says the route can clear the 4 ETH target.

## Post 7/8

6/ The execution is four calls:

1. Uniswap V1: swap 0.1 ETH → KNC
2. approve + `deposit` KNC into DutchX
3. `postBuyOrder(WETH, KNC, 1051, allKNC)`
4. `claimBuyerFunds`, withdraw WETH, unwrap WETH → ETH

Key detail: buyer funds are claimable while the auction is still open.

## Post 8/8

7/ I used an archive RPC + Foundry fork for reproducibility:

`python3 alpha.py check 02` → 100/100.

If you have Tenderly, create a VNet/fork at block `9,462,777` and execute the 4 calls one by one. The traces make ETH → KNC → DutchX credit → WETH → ETH much easier to see.
