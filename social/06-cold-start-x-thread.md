# X thread draft — Wintermute Alpha Challenge 2026, Case 06

## Post 1/9

Wintermute Alpha Challenge 2026, case 06: “Cold Start”.

Goal: buy 1M CASHCAT on a brand-new Arbitrum-style L2 with no usable RPC, explorer or bridge UI.

The entry point left open? Ethereum’s Delayed Inbox. 👇

## Post 2/9

1/ Read the harness before touching contracts. `_relay()` is the spec:

it reads an Inbox log, extracts an L2 destination, ETH value and calldata, then executes that call on the L2 fork as `alias(USER_ADDRESS)`.

## Post 3/9

2/ This is not a normal L2 tx. We create an L1 retryable ticket:

`createRetryableTicket(to, l2CallValue, fees, refunds, gas, calldata)`

It is a protocol message: “when included on L2, call this target with these bytes and this ETH.”

## Post 4/9

3/ Where does CASHCAT come from? Do not assume a mint exploit.

Filtering `Transfer(from=0x0)` finds the 1B initial mint. The creator approved it to Uniswap V3’s Position Manager, which seeded a real liquidity position. We buy from that pool.

## Post 5/9

4/ Derive infrastructure on-chain, don’t guess addresses:

Position Manager → `factory()` + `WETH9()`

Factory → `getPool(CASHCAT, WETH, fee)`

Result: CASHCAT/WETH at the 1% tier. Its spot price suggested ~0.155 ETH for 1M tokens.

## Post 6/9

5/ Then simulate the *inner* L2 call. A 0.20 ETH swap through SwapRouter02 returned 1,259,632 CASHCAT.

Set `amountOutMinimum = 1_000_000e18`: if price impact is worse than expected, the ticket reverts instead of quietly failing the target.

## Post 7/9

6/ ABI gotcha: SwapRouter02 is not the older V3 router. Its `exactInputSingle` params have **no deadline** field.

Using the old struct changes the selector. Same address, apparently sensible call, instant revert. Always verify the ABI, not just the contract label.

## Post 8/9

7/ The L1 ETH is split into three parts:

`L2 call value` + `submission fee` + `L2 gas budget`

Only 0.20 ETH reaches the L2 router. It wraps ETH→WETH internally, swaps in the pool, and sends CASHCAT directly to the original user address.

## Post 9/9

8/ The reusable model:

L1 Inbox → retryable ticket → aliased L2 caller → router → existing AMM liquidity → chosen recipient.

No UI is required; no tokens are fabricated. The message ingress is enough to execute a real L2 trade.
