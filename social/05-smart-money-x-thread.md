# X thread draft — Wintermute Alpha Challenge 2026, Case 05

## Post 1/8

Wintermute Alpha Challenge 2026, case 05: “Smart Money” (100 pts).

Two fundraise wallets, an anonymous VC wallet, and a counterparty with billions in volume.

The lesson: amounts are weak evidence. Build candidate sets, then eliminate. 👇

## Post 2/8

1/ Start with the first address, `0xAf09…`. Its early stablecoin inflows look like a raise, but its later history includes treasury and CEX activity.

Never total a wallet's entire lifetime and call it “the round.” Restrict the time window first.

## Post 3/8

2/ The historical announcement identifies that raise as C3 Protocol’s $3.6m round. Great — but it lists many VCs, including Node, Arrington, Jump, ParaFi and others.

So this identifies the *protocol*, not the anonymous investor wallet.

## Post 4/8

3/ Investigate `0xC29…` independently. It receives a large ETHFI allocation via the ether.fi investor-distribution/custody route:

`ether.fi Investors → Anchorage → 0xC29…`

That is evidence of an investor allocation, not a DEX purchase.

## Post 5/8

4/ Cross the two investor lists:

`C3 investors ∩ ether.fi investors = {Node Capital, Arrington Capital}`

Still not enough. The key final check: Arrington’s wallet is publicly tagged and it is not `0xC29…`. The remaining candidate is Node Capital.

## Post 6/8

5/ Notice what we did *not* do: infer a VC from the ETHFI amount or claim we know its cheque size.

The evidence is a chain of constraints: allocation recipient → shared investor sets → tagged-wallet exclusion.

## Post 7/8

6/ The second case is the same workflow. A fresh `0xe53e…` wallet receives about $20m in a bounded window: that matches Aligned Layer’s Series A. One source is `0x4c2c…`, a high-volume wallet attributable to Bridge.

## Post 8/8

7/ Save the four names and verify:

`python3 alpha.py check 05` → 100/100.

Reusable principle: on-chain flows classify behaviour; public disclosures create candidates; independent wallet evidence resolves identity. Never let a round’s amount do more work than it can.
