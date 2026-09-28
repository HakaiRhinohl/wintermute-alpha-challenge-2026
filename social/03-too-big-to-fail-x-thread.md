# X thread draft — Wintermute Alpha Challenge 2026, Case 03

## Post 1/7

Wintermute Alpha Challenge 2026, case 03: “Too Big To Fail” (100 pts).

At block 12,465,029, turn 0.1 ETH into 2,500+ ETH.

The route was a single Liquity liquidation. The key was understanding Recovery Mode, not buying $900M of LUSD. 👇

## Post 2/7

1/ Pin the fork to the challenge block first. Current prices and current protocol state are irrelevant.

Inspect borrower `0x903d...Cce3` through Liquity's contracts at block `12,465,029`: price, debt, collateral, ICR, system mode and Stability Pool deposits.

## Post 3/7

2/ The historical reads:

- debt: ~900M LUSD
- collateral: 606,280 ETH
- ETH price: $1,976.54
- ICR: 133.15%
- Stability Pool: ~1.076B LUSD
- system: Recovery Mode

ICR is this Trove's ratio. Recovery Mode is a property of the *whole system*.

## Post 4/7

3/ Liquity enters Recovery Mode when system-wide TCR drops below 150%.

Then a Trove with `110% <= ICR < 150%` can be liquidated if the Stability Pool covers its debt.

Here: `1.076B LUSD in the pool > 900M LUSD debt`. So the 133.15% Trove is eligible.

## Post 5/7

4/ Why no $900M LUSD or flash loan?

The caller does not repay the debt. Liquity burns LUSD already deposited in the Stability Pool, sends the collateral to its depositors, and pays the caller a liquidation reward for executing the transaction.

## Post 6/7

5/ The caller receives 0.5% of the Trove collateral as ETH gas compensation:

`606,280 ETH × 0.5% = 3,031.4 ETH`

That alone beats the 2,500 ETH target. The entire solution is permissionless:

`TroveManager.liquidate(borrower)`

## Post 7/7

6/ Verify with:

`python3 alpha.py check 03`

For a visual pass, use a Tenderly VNet/fork at block `12,465,029`, fund 0.1 ETH, simulate `liquidate`, and inspect the trace. You will see Stability Pool LUSD offset the debt and 3,031.4 ETH reach the caller.
