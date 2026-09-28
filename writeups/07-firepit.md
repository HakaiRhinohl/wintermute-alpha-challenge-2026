# Firepit — harvesting and liquidating Uniswap protocol fees on X Layer

> Status: solution implemented. Run `python3 alpha.py check 07` locally to
> record the final score.

## Objective

At X Layer block `68,413,600`, the wallet starts with `2,000 UNI` and must end
with at least `45,000 USD₮0`.

The opportunity is not an ownership bug. It is the intended Uniswap fee
mechanism: an open adapter can move accumulated V3 protocol fees into a
TokenJar, and a releaser transfers selected assets from that jar in exchange
for a fixed UNI payment.

## The three contracts that matter

```text
V3 pool ── collect() ──> V3OpenFeeAdapter ──> TokenJar
                                                  │
                                   release(UNI)   │ selected tokens
USER ───────────────────────────────> Firepit ───┘
                                                  │
                                                  ▼
                                            USER wallet
```

- **V3OpenFeeAdapter** — `collect()` is permissionless. It asks a pool to send
  its accumulated protocol fees to the TokenJar.
- **TokenJar** — custody for the collected tokens.
- **Firepit / ExchangeReleaser** — takes the UNI threshold from the caller and
  releases an explicit list of assets from the jar to a recipient. The
  official implementation limits that list to 20 assets and uses a nonce to
  prevent replay. [Source](https://github.com/Uniswap/protocol-fees/blob/main/src/releasers/ExchangeReleaser.sol)

The key consequence is that collecting a token and claiming it are separate
decisions. A caller can collect fees broadly, then release only the assets it
can sell sensibly.

## Finding the fee basket

Start from the official X Layer V3 factory, not from a token list or a UI.
Search its historical `PoolCreated` events up to the fork block, filtering for
`USD₮0` as either `token0` or `token1`. This produced 76 candidate pools.

For each candidate, simulate:

```solidity
adapter.collect([CollectParams(pool, type(uint128).max, type(uint128).max)]);
```

Each collection must be isolated. One candidate reverted with `LOK`; putting
all pools in one call would make that single revert erase the rest of the
collection. In the final transaction, each pool is attempted independently
with `try/catch`.

The successful calls put, among other assets, the following amounts in the
TokenJar:

| Asset | Amount |
| --- | ---: |
| USD₮0 | 26,570.237066 |
| WOKB | 134.299654224125748759 |
| xBTC | 0.04374949 |
| USDG | 2,712.818973 |
| xETH | 2.299560121383716032 |

Do not treat a token balance as its USD value. The next question is whether the
*full amount* can actually be sold at the historical block.

## Choosing executable exits

For each collected token, ask the factory for pools at every enabled fee tier,
check that `liquidity()` is non-zero, and quote the **whole** collected amount
with the V3 quoter. The selected direct routes were:

| Sale | V3 fee tier | USD₮0 output |
| --- | ---: | ---: |
| WOKB → USD₮0 | 500 (0.05%) | 13,774.451982 |
| xBTC → USD₮0 | 100 (0.01%) | 2,960.137037 |
| USDG → USD₮0 | 100 (0.01%) | 2,714.585376 |

Together with the USD₮0 already collected, this yields:

```text
26,570.237066
+13,774.451982
 +2,960.137037
 +2,714.585376
----------------
 46,019.411461 USD₮0
```

That is about `1,019.41 USD₮0` above the target.

### Why xETH is not claimed

The direct xETH route had non-zero liquidity, but quoting the entire
`2.299560121383716032 xETH` produced only `7.085746 USD₮0`. This is a liquidity
and price-impact problem, not a statement that ETH is intrinsically worth $7.

Because `release()` accepts an asset list, the solution simply omits xETH. It
remains in the TokenJar instead of being dumped into a bad pool. The same
principle applies to every dust token in the basket.

## Execution

The final solution performs four actions in one fork transaction:

1. Attempt collection for every candidate pool separately.
2. Approve Firepit to take `2,000 UNI`.
3. Call `release(0, [USD₮0, WOKB, xBTC, USDG], user)`.
4. Swap WOKB, xBTC and USDG through the three routes above.

The implementation is in
[`challenges/07-firepit/Solution.t.sol`](../challenges/07-firepit/Solution.t.sol).

```bash
python3 alpha.py check 07
```

## What matters outside a challenge fork

- **Quote the full size, not one token.** A pool can have non-zero liquidity
  and still be unusable for the actual position size.
- **Keep collection failure-isolated.** Permissionless does not mean every
  historical pool is collectable at every state.
- **Use a narrow release list.** The releaser has a maximum asset count, and
  releasing an asset without an exit wastes gas and can destroy value.
- **Protect swaps.** `amountOutMinimum = 0` is acceptable only in this
  deterministic exercise. A live transaction needs fresh quotes, conservative
  minimum outputs and a profitability calculation that includes 2,000 UNI,
  gas, and price impact.
- **Expect competition.** Collection, release and swaps are public calls. A
  real searcher must account for state changing between discovery and inclusion.
