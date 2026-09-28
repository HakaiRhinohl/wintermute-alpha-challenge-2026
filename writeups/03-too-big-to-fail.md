# Too Big To Fail — a billion-dollar Liquity liquidation

> Status: solution ready; verify locally with `python3 alpha.py check 03`.

## Objective

At Ethereum block `12,465,029` (19 May 2021), turn the challenge's 0.1 ETH
into more than 2,500 ETH.

The target is Liquity borrower
[`0x903d12bf2c57A29f32365917c706ce0e1a84Cce3`](https://etherscan.io/address/0x903d12bf2c57A29f32365917c706ce0e1a84Cce3).
The interesting question is not whether the position is large. It is whether
Liquity considers it eligible for liquidation at that historical block, and
who supplies the LUSD needed to cancel its debt.

## 1. Pin the historical state

This is a historical-state problem. A current Liquity explorer or a current ETH
price cannot answer it. The test creates a mainnet fork pinned to block
`12,465,029` and gives the challenge address 0.1 ETH.

The read-only inspector is reproducible with:

```bash
forge test \
  --match-path challenges/03-too-big-to-fail/LiquityInspector.t.sol \
  --match-test test_InspectBorrower \
  -vv
```

## 2. Inspect the Trove and system state

At the fork block, Liquity reports:

| Value | Historical result |
|---|---:|
| ETH/USD price used by Liquity | $1,976.54 |
| Trove debt | ~899,999,899.22 LUSD |
| Trove collateral | 606,280 ETH |
| Individual collateral ratio (ICR) | 133.1485% |
| Liquity system mode | Recovery Mode |
| LUSD in Stability Pool | ~1,076,032,270.14 LUSD |
| Pending debt/collateral rewards | 0 / 0 |

The ICR is the value of this Trove's ETH collateral divided by its LUSD debt:

```text
ICR = collateral × ETH/USD price / debt
    = 606,280 × 1,976.54 / 899,999,899.22
    ≈ 133.1485%
```

An ICR of 133% is above Liquity's normal 110% minimum collateral ratio. That
alone would make the position look safe. The system mode changes the rule.

## 3. Why Recovery Mode makes it liquidatable

Liquity enters Recovery Mode when the **total collateral ratio** of the entire
system (TCR), not an individual Trove's ICR, falls below its 150% critical
collateral ratio.

In Recovery Mode, a Trove with an ICR between 110% and 150% can be liquidated
when the Stability Pool has enough LUSD to offset its full debt. Here:

```text
Trove debt:       ~900.0M LUSD
Stability Pool: ~1,076.0M LUSD
```

The pool can absorb the whole debt, so this 133% ICR Trove is liquidatable. The
position is huge, but its size is not an obstacle: the Stability Pool is even
larger.

## 4. Why the liquidator does not need to buy LUSD

The caller does not repay the debt personally. Calling `liquidate` triggers
Liquity's settlement process:

```text
Stability Pool LUSD  → burned to offset the Trove's debt
Trove ETH collateral → distributed to Stability Pool depositors
0.5% of collateral   → sent to the liquidation caller as ETH compensation
200 LUSD reserve     → sent to the liquidation caller
```

The Stability Pool exists specifically to provide this liquidation liquidity;
its depositors accept LUSD losses in exchange for the liquidated ETH collateral.
The liquidator is an execution agent, not the debt financier.

## 5. Calculate the reward before executing

Liquity pays the caller 0.5% of the Trove collateral as ETH gas compensation:

```text
606,280 ETH / 200 = 3,031.4 ETH
```

This is already above the challenge target of 2,500 ETH. The 200 LUSD
liquidation reserve is additional compensation, but it is not needed to pass.

## 6. Execute the liquidation

The entire solution is one permissionless contract call:

```solidity
ITroveManager(TROVE_MANAGER).liquidate(BORROWER);
```

It is implemented in
[`challenges/03-too-big-to-fail/Solution.t.sol`](../challenges/03-too-big-to-fail/Solution.t.sol).

Run the local verifier:

```bash
python3 alpha.py check 03
```

The account starts with 0.1 ETH; the liquidation compensation should leave it
with more than 2,500 ETH.

## Optional visual workflow with Tenderly

An archive RPC and Foundry fork are enough to reproduce the investigation. If
you have Tenderly VNet / Virtual TestNet access, it can make the mechanism much
easier to inspect:

1. Fork Ethereum at block `12,465,029`.
2. Fund a test wallet with 0.1 ETH.
3. Simulate `TroveManager.liquidate(borrower)`.
4. Inspect the trace: Stability Pool LUSD is offset, collateral is allocated,
   and the caller receives the ETH gas compensation.

Treat the VNet as a visual debugger, not as the evidence source. Pinning the
block remains essential, and Tenderly feature availability may depend on plan.

## Lessons

- Distinguish an individual ICR from the protocol-wide TCR: Recovery Mode is
  triggered by the latter.
- A liquidation caller may only need to send a transaction. The protocol's
  Stability Pool can supply the debt-offsetting stablecoins.
- Always test the exact mode and available Stability Pool liquidity. “ICR above
  110%” is not sufficient to rule out liquidation in Recovery Mode.
- Large collateral can turn a fixed percentage gas compensation into an
  extraordinary execution opportunity.

## References

- [Liquity V1: Stability Pool and liquidations](https://docs.liquity.org/liquity-v1/faq/stability-pool-and-liquidations)
- [Liquity V1: Recovery Mode rules](https://docs.liquity.org/liquity-v1/faq/recovery-mode)
- [Liquity V1 technical resources and mainnet addresses](https://docs.liquity.org/liquity-v1/documentation/resources)
