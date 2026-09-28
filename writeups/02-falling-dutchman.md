# Falling Dutchman — buying a stale Dutch auction

> Status: draft

## Objective

At Ethereum block `9,462,777`, turn the 0.1 ETH provided by the Wintermute
Alpha Challenge into at least 4 ETH.

The challenge is not about predicting a current market price. It is a
historical-state exercise: every read and every trade below runs against an
Ethereum fork pinned to that exact February 2020 block.

## The hypothesis

[DutchX](https://dutchx.readthedocs.io/en/latest/) was a Dutch-auction exchange.
For an active auction, its price starts high and decays over time until buyers
take the sell-side liquidity. A useful question is therefore:

> Is DutchX offering an asset more cheaply than another venue at this exact
> historical block?

The local challenge funds the player with only 0.1 ETH, so a successful route
must be an unusually large price discrepancy, not a normal arbitrage.

## 1. Find the active historical auction

The fork block is `9,462,777`. Explorer pages are not reliable for this step:
they normally show the contract's current state, not the state in 2020.

[`scripts/list_dutchx_auctions.py`](../scripts/list_dutchx_auctions.py) queries
the `AuctionStartScheduled` event directly from an archive RPC, in small
1,000-block ranges. Small ranges matter because many RPC providers reject a
large `eth_getLogs` query.

```bash
python3 scripts/list_dutchx_auctions.py
```

It finds the relevant event:

```text
Block 9,456,378  auction #1051
sell:  WETH  0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
buy:   KNC   0xdd974D5C2e2928deA5F71b9825b8b646686BD200
start: 2020-02-10 17:14 UTC
```

The `sell` / `buy` order is important. This auction sells WETH; buyers pay in
KNC. The event only tells us that the auction was scheduled. We still need to
inspect its state at the fork block.

## 2. Read the auction state at the fork block

Run the read-only Foundry inspector:

```bash
forge test \
  --match-path challenges/02-falling-dutchman/AuctionInspector.t.sol \
  --match-test test_InspectAuction \
  -vv
```

The relevant output is:

```text
auction index 1051
current price numerator 17033467344264227443149225
current price denominator 1172190779636348006673750
previous closing price numerator 5823407639064693142957
previous closing price denominator 9253528949171880850
current WETH sell volume (raw) 4482232591529073942
current KNC buy volume (raw) 0
clearing time (0 means not cleared) 0
```

DutchX's `getCurrentAuctionPrice(token1, token2, index)` returns a fraction in
units of `token2 / token1`. Therefore, with `token1 = WETH` and `token2 = KNC`:

```text
current price
= 17,033,467,344,264,227,443,149,225
  / 1,172,190,779,636,348,006,673,750
= 14.53130978 KNC per WETH

previous closing price
= 5,823,407,639,064,693,142,957
  / 9,253,528,949,171,880,850
= 629.31749293 KNC per WETH
```

No extra decimal conversion is needed for these two ratios: both WETH and KNC
use 18 decimals, so the scale cancels out.

The auction price has decayed by:

```text
629.31749293 / 14.53130978 = 43.30769...
```

At this point DutchX asks about 43.3 times less KNC per WETH than the prior
auction's closing price. It also has `4.482232591529073942 WETH` on its sell
side and has not cleared. That is enough inventory for the challenge target.

## 3. Price KNC on a second venue

Cheap WETH alone is not sufficient: the player starts with ETH, while DutchX
requires KNC. We need a historical venue where 0.1 ETH can buy KNC first.

At the fork block, Uniswap V1's factory returns the KNC exchange
`0x49c4f9bc14884f6210F28342ceD592A633801a8b`. The read-only inspector asks that
exchange for its exact-input quote:

```bash
forge test \
  --match-path challenges/02-falling-dutchman/ExternalPriceInspector.t.sol \
  --match-test test_InspectKncMarket \
  -vv
```

Result:

```text
input:  0.1 ETH
output: 62.865191752838287641 KNC
```

DutchX charges up to 0.5% for a buyer with no fee-reduction tokens. Conservatively:

```text
KNC available to the auction
= 62.865191752838287641 × 0.995
≈ 62.550865793 KNC

WETH claimable at the observed auction price
≈ 62.550865793 / 14.53130978
≈ 4.304 WETH
```

This is above the required 4 ETH. The numbers establish the route before we
write the transaction sequence.

## 4. Execute the route

The solution in
[`challenges/02-falling-dutchman/Solution.t.sol`](../challenges/02-falling-dutchman/Solution.t.sol)
does exactly four things:

1. Call Uniswap V1's `ethToTokenSwapInput`, sending the challenge's 0.1 ETH,
   to receive KNC.
2. Approve DutchX, then `deposit` all KNC into its internal balance.
3. Call `postBuyOrder(WETH, KNC, 1051, kncBalance)`.
4. Call `claimBuyerFunds`, `withdraw` the resulting WETH from DutchX, then
   call WETH's `withdraw` to unwrap it into native ETH.

The subtle part is step 4. The auction does **not** have to clear. While it is
still running, `claimBuyerFunds` credits the buyer with the amount already
implied by their KNC balance and the current auction price. The relevant DutchX
logic calculates that amount as:

```text
buyerBalance × priceDenominator / priceNumerator
```

That is why spending roughly 62.55 KNC at 14.53 KNC/WETH yields roughly 4.30
WETH immediately.

Run the challenge's local verifier:

```bash
python3 alpha.py check 02
```

It should report `100/100 points` and an ending native-ETH balance above 4 ETH.

## Optional visual workflow with Tenderly

The scripts and Foundry tests are the reproducible method and require only an
archive RPC. If you have a Tenderly account with Virtual TestNet / VNet access,
it is also a very good learning tool:

1. Create a fork or VNet pinned to mainnet block `9,462,777`.
2. Fund a test wallet with 0.1 ETH.
3. Execute the four calls above one at a time.
4. Inspect each transaction's call trace and token-balance changes.

This makes the flow visual: ETH becomes KNC on Uniswap, KNC moves into DutchX,
DutchX credits WETH, and WETH unwraps back into ETH. It is optional because
Tenderly features and plan availability can vary; the local Foundry fork is the
portable source of truth.

## 

## References

- [DutchX documentation](https://dutchx.readthedocs.io/en/latest/)
- [DutchX source: auction and buyer-claim logic](https://github.com/gnosis/dx-contracts/blob/master/contracts/DutchExchange.sol)
- [Uniswap V1 exchange interface](https://github.com/Uniswap/v1-contracts/blob/master/contracts/uniswap_exchange.vy)
