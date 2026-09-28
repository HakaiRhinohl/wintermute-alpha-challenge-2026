# X thread draft — Wintermute Alpha Challenge 2026, Case 07

## Post 1/8

Wintermute Alpha Challenge 2026, case 07: “Firepit”.

The task: start with 2,000 UNI on X Layer and finish with 45,000 USD₮0.

The mechanism is not a contract takeover. It is a permissionless protocol-fee release system. 👇

## Post 2/8

1/ The system has three pieces:

V3 pools accrue protocol fees.

An open adapter can `collect()` those fees into a TokenJar.

A releaser accepts 2,000 UNI and sends selected Jar assets to the caller.

So the question is not “can I call it?” Anyone can. It is “is the jar worth more than the UNI?”

## Post 3/8

2/ Start from the factory, not from a UI or a token list.

I filtered historical `PoolCreated` events for pools containing USD₮0, then simulated `collect()` at the challenge block.

That identified 76 candidate pools and a basket already containing 26,570 USD₮0, plus WOKB, xBTC, USDG and other tokens.

## Post 4/8

3/ Important implementation detail: collect each pool independently.

One candidate returned `LOK`.

If all pools were put into one batch, that single revert would roll back every successful collection. Isolated calls let the useful pools settle even when one is uncollectable.

## Post 5/8

4/ A token balance is not a dollar balance.

For each collected asset, I checked every enabled fee tier, required non-zero active liquidity, then quoted the *entire* balance through the V3 quoter.

The best direct exits were:

WOKB → USD₮0: 13,774.45
xBTC → USD₮0: 2,960.14
USDG → USD₮0: 2,714.59

## Post 6/8

5/ Add those to the USD₮0 already in the TokenJar:

`26,570.24 + 13,774.45 + 2,960.14 + 2,714.59 = 46,019.41 USD₮0`

That clears the 45k target after paying the 2,000 UNI release threshold.

## Post 7/8

6/ I did **not** claim xETH.

It was not worthless; the available direct pool was simply too shallow. Quoting the full 2.30 xETH balance returned roughly 7 USD₮0.

The releaser lets the caller choose its asset list, so xETH stays in the TokenJar instead of being sold at a nonsensical price.

## Post 8/8

7/ The reusable playbook:

factory events → collectability simulation → aggregate the Jar → quote full-size exits → claim only liquid assets → protect execution.

On a live chain, use fresh quotes and strict `amountOutMinimum` values. All steps are public and the opportunity can disappear between discovery and inclusion.
