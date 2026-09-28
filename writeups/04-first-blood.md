# First Blood — reconstructing a Solana token launch

> Status: solved locally (`100/100`).

## Objective

For the launch of Official TRUMP on Solana, identify:

1. the first attempt to snipe the token; and
2. the transaction that made trading possible.

This is not a search for the first successful buy. The two requested events are
different: a bot can prepare an attempted route before a pool is tradeable, and
an administrative transaction can enable trading without moving a single token.

## 1. Establish the token and the pool

Start from the official TRUMP mint, not the ticker symbol:

```text
TRUMP mint: 6p6xgHyF7AeE6TZkSmFsko444wqoP15icUSqi2jfGiPN
USDC mint:  EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v
```

On Solscan, use the token's Markets tab to identify the launch's Meteora DLMM
TRUMP/USDC pool:

```text
Pool: A8nPhpCJqtqHdqUk35Uj9Hy2YsGXFkCZGuNwvkD3k7VC
```

The pool account is the useful investigation pivot. The TRUMP mint has more
than a million transfers; the pool's own history is much smaller and preserves
the launch sequence.

## 2. Separate pool setup from trading

Open the pool with **Oldest First** selected. The early calls are made by the
liquidity provider and are expected setup operations:

```text
Pool: Create
initializeBinArray
Position: Open
Liquidity: Add
```

These calls establish a market and deposit inventory. They do not prove that
public swaps are enabled.

This distinction matters on Solana:

| Explorer page | What it can prove | What it misses |
|---|---|---|
| Token → Transfers | A TRUMP balance moved | Administrative calls with no TRUMP transfer |
| Pool → Transactions | Every call touching the pool | The balance-direction summary of a completed trade |

Use both pages together.

## 3. Find the transaction that enabled trading

In the pool's **Transactions** history, filter to the pool controller's
administrative calls and inspect the Meteora DLMM program logs. The relevant
transaction is:

```text
4SMUTho76nrPXxGNdDBNdBNbtbSC48oDDkivVKSdWUJR8KZGQwv1tEwJnHFXmpFDFkkLRupzzW28e6HHpv49afQt
```

It was confirmed at `2025-01-18 02:01:32 UTC` and logs:

```text
Instruction: TogglePairStatus
```

`TogglePairStatus` switches the DLMM pair between enabled and disabled. The
instruction alone does not encode a human-readable direction in the explorer,
so validate it by looking at what follows. One second later, transaction
`3SZDNu18GmCrNRH3ty3MxX31sez8Ge5bAvw7SbgD4zQmFjJJMPoztwQeh6mcr8vVM7eh57T3jAcQSqGEVP29sXwY`
executes a real `Swap`, with TRUMP leaving the pool and token transfers on both
sides of the route.

That chronological before/after evidence proves that this status update enabled
trading.

## 4. Find the first snipe attempt

Go back to the period before the enabling transaction. Do not filter only for
`Swap`: the first relevant bot transaction does not complete a trade.

Instead, find the earliest non-setup transaction that references all three
launch-specific accounts at once:

```text
TRUMP mint + USDC mint + the TRUMP/USDC Meteora pool
```

The first such transaction is:

```text
41h3CuLHamSdfsmgWC887eoyvrTiUcGjhLZpKMeqE9Rg9ZkP42C2gBr5PrQM9D25jRFwwQYPfBUJYCEUXC1qAxcv
```

It confirmed at `2025-01-17 22:05:52 UTC`. Its instruction invokes a bot
program and includes the TRUMP mint, USDC mint and pool account, but its balance
changes show no completed TRUMP/USDC swap. This is why it is correctly called
the first **attempt** to snipe, rather than the first purchase.

## 5. Result and verification

Write the two signatures in `challenges/04-first-blood/answer.txt`:

```text
first_snipe = 41h3CuLHamSdfsmgWC887eoyvrTiUcGjhLZpKMeqE9Rg9ZkP42C2gBr5PrQM9D25jRFwwQYPfBUJYCEUXC1qAxcv
trading_possible = 4SMUTho76nrPXxGNdDBNdBNbtbSC48oDDkivVKSdWUJR8KZGQwv1tEwJnHFXmpFDFkkLRupzzW28e6HHpv49afQt
```

Then run:

```bash
python3 alpha.py check 04
```

The local checker reports `100/100`.

## Lessons

- On-chain “first” depends on the definition. The first snipe attempt, first
  successful swap and trading-enablement transaction are separate events.
- An event with no token transfer can be the most important event in a launch.
- Trace the same pool in two views: its transaction history for control-plane
  changes and token transfers for execution-plane evidence.
- Do not infer `enabled` from the name `TogglePairStatus`; prove the direction
  from the immediately following successful swaps.

## References

- [Official TRUMP mint on Solscan](https://solscan.io/token/6p6xgHyF7AeE6TZkSmFsko444wqoP15icUSqi2jfGiPN)
- [Meteora DLMM status controls](https://github.com/MeteoraAg/docs/blob/main/developer-guides/dlmm/typescript-sdk/reference.mdx)
