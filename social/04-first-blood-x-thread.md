# X thread draft — Wintermute Alpha Challenge 2026, Case 04

## Post 1/8

Wintermute Alpha Challenge 2026, case 04: “First Blood” (100 pts).

Find the first TRUMP snipe attempt on Solana and the tx that made trading possible.

The trick: first attempt ≠ first successful buy, and the enabling tx moves no TRUMP. 👇

## Post 2/8

1/ Start from the official mint, not the ticker:

`6p6xgHyF7AeE6TZkSmFsko444wqoP15icUSqi2jfGiPN`

On Solscan → Markets, identify the launch Meteora DLMM TRUMP/USDC pool. Investigate the pool account: a mint's transfer history is far too noisy.

## Post 3/8

2/ Set the pool's **Transactions** tab to Oldest First.

The first calls are setup: create pool, initialise bin arrays, open positions, add liquidity. They make inventory available, but do not prove that anyone can swap yet.

## Post 4/8

3/ Do not look for `TogglePairStatus` in TRUMP → Transfers.

It is an admin call with no TRUMP movement, so it is invisible there. Filter the pool's *transaction* history to Meteora DLMM/control-wallet calls and inspect logs instead.

## Post 5/8

4/ A toggle's name does not tell you its direction. Validate it chronologically:

`TogglePairStatus` → next tx has `Swap` + real TRUMP/USDC transfers.

That proves the pool changed from disabled to enabled. The first successful swap is evidence, not the answer itself.

## Post 6/8

5/ Now move backwards. Do not filter only for swaps.

The first snipe attempt can be a bot-priming tx with no completed trade. Find the earliest non-setup tx that references all three launch accounts: TRUMP mint, USDC mint and the Meteora pool.

## Post 7/8

6/ Inspect balance changes. If TRUMP and USDC do not move, it was not a completed buy — but its account list can still prove a bot knew the exact future route before trading was live.

That is the distinction the challenge tests: intent vs execution.

## Post 8/8

7/ Save the two signatures and verify locally:

`python3 alpha.py check 04` → 100/100.

The reusable method: pool transaction history explains state changes; token transfers prove executions. You need both to reconstruct a launch honestly.
