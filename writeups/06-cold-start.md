# Cold Start — executing a Uniswap swap through an L1-to-L2 retryable ticket

> Status: solution implemented; run `python3 alpha.py check 06` locally to
> record the final score.

## Objective

Robinhood Chain is presented as a newly launched Arbitrum-style L2. There is no
usable L2 RPC, bridge UI or explorer. The only available entry point is the L1
Delayed Inbox. The task is to make `USER_ADDRESS` hold at least 1,000,000
CASHCAT on the L2.

The solution does not mint tokens or impersonate the token creator. It sends
ETH and a swap instruction through the canonical L1-to-L2 message path, then
buys CASHCAT from its existing Uniswap V3 liquidity pool.

## Architecture

Ethereum and an L2 have separate state and separate transaction execution. A
transaction sent to Ethereum cannot directly call an L2 contract. An Inbox is
the protocol bridge between them.

```text
USER_ADDRESS on Ethereum
  │
  │ createRetryableTicket(value, L2 destination, L2 calldata)
  ▼
Delayed Inbox on L1
  │ emits a message
  ▼
challenge relay harness
  │ executes the embedded call as alias(USER_ADDRESS)
  ▼
SwapRouter02 on Robinhood Chain
  │ wraps ETH to WETH and swaps in the V3 pool
  ▼
USER_ADDRESS receives CASHCAT
```

The harness deliberately simplifies production infrastructure:

- it funds the user with 10 ETH on the L1 fork;
- it disables the Inbox allowlist using the privileged Rollup address;
- it immediately relays every Inbox message rather than waiting for normal
  sequencing/inclusion; and
- it executes the L2 call as `alias(USER_ADDRESS)`.

It does **not** give the user permission to mint CASHCAT or take tokens from
the creator. The L2 call still has to obey the real contracts at the forked
block.

## Fast path

This is the shortest reproducible investigation route.

### 1. Read the harness first

`_relay()` in `Solution.t.sol` is the specification for the message format. It
collects Inbox logs, decodes a byte payload and extracts:

```text
word 0: L2 destination address
word 1: L2 call value
word 8: embedded calldata length
remaining bytes: embedded calldata
```

This strongly suggests an Arbitrum retryable ticket. The Inbox exposes:

```solidity
createRetryableTicket(
    address to,
    uint256 l2CallValue,
    uint256 maxSubmissionCost,
    address excessFeeRefundAddress,
    address callValueRefundAddress,
    uint256 gasLimit,
    uint256 maxFeePerGas,
    bytes data
)
```

Its ABI encoding has the same layout observed by `_relay()`.

### 2. Locate the pool through standard Uniswap read methods

The CASHCAT contract is:

```text
0x020bfC650A365f8BB26819deAAbF3E21291018b4
```

An approval by the initial holder points to the Robinhood Chain Uniswap V3
Nonfungible Position Manager:

```text
0x73991a25C818Bf1f1128dEAaB1492D45638DE0D3
```

Read `factory()` and `WETH9()` from that contract, then call
`factory.getPool(CASHCAT, WETH, feeTier)` for common fee tiers. The live pool
at the fork is:

```text
factory: 0x1f7d7550B1b028f7571E69A784071F0205FD2EfA
WETH:    0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73
pool:    0xA70fc67C9F69da90B63a0e4C05D229954574E313
fee:     10,000 = 1%
```

`CASHCAT` is `token0` and `WETH` is `token1`. The observed square-root price
implies a spot cost of roughly `0.155 ETH` for 1,000,000 CASHCAT. That is only
a starting estimate: fee and price impact require an execution simulation.

### 3. Simulate the exact L2 call

Use the chain's `SwapRouter02`:

```text
0xCaf681a66D020601342297493863E78C959E5cb2
```

The important ABI detail is that `SwapRouter02.ExactInputSingleParams` has no
`deadline` field. The older V3 router interface includes one; using that older
struct changes the ABI function selector and causes an immediate revert.

With the correct `SwapRouter02` ABI, a simulated single-hop swap gives:

```text
input:  0.20 ETH
output: 1,259,632 CASHCAT
```

The router receives native ETH, wraps it into WETH internally, sends WETH to
the pool and sends CASHCAT directly to `USER_ADDRESS`. Set
`amountOutMinimum` to `1_000_000e18`; this makes the ticket revert rather than
silently missing the target.

## Deep path: reconstructing the launch

The fast path does not require a full token-history investigation. It is still
useful for explaining where the purchasable CASHCAT originates.

Filter the ERC-20 `Transfer` event with `from = address(0)`. At block `88,836`
the contract minted its entire supply:

```text
0x0000000000000000000000000000000000000000
  → 0xd9ec2db5f3d1b236843925949fe5bd8a3836fccb
  1,000,000,000 CASHCAT
```

At the same block, that holder approved the full supply to the Position
Manager. This is normal launch mechanics: the position manager pulls tokens to
create a concentrated-liquidity position. It is not an approval available to
the user; only the approved spender can use it.

## Constructing the ticket

The inner L2 calldata is built by Solidity, not written byte-by-byte:

```solidity
bytes memory l2Calldata = abi.encodeWithSelector(
    ISwapRouter02.exactInputSingle.selector,
    ISwapRouter02.ExactInputSingleParams({
        tokenIn: WETH,
        tokenOut: CASHCAT,
        fee: 10_000,
        recipient: user,
        amountIn: 0.20 ether,
        amountOutMinimum: 1_000_000e18,
        sqrtPriceLimitX96: 0
    })
);
```

The ETH attached to the L1 transaction has three distinct components:

```text
L1 value
= L2 call value
+ retryable submission fee
+ L2 gas budget (gasLimit × maxFeePerGas)
```

At the fork this was:

```text
L1 ETH attached:        0.200507049011771632 ETH
L2 call value:          0.200000000000000000 ETH
submission fee:         0.000007049011771632 ETH
retryable gas budget:   0.000500000000000000 ETH
```

`calculateRetryableSubmissionFee(l2Calldata.length, block.basefee)` obtains
the required submission fee from the Inbox rather than guessing it. Both refund
addresses are set to the user.

Although the L2 call originates from `alias(USER_ADDRESS)`, the router's
`recipient` field is the original `USER_ADDRESS`. This is why the final
balance check succeeds for the non-aliased address.

## Verification and supporting tools

The final implementation is in
`challenges/06-cold-start/Solution.t.sol`.

```bash
python3 alpha.py check 06
```

The supporting reconnaissance files are deliberately read-only or disposable
fork simulations:

- `L2Inspector.t.sol`: token metadata, supply and user/alias balances;
- `scripts/inspect_cashcat_launch.py`: filters the mint event, respecting the
  RPC's 10,000-block log-query limit;
- `scripts/inspect_cashcat_approvals.py`: finds approvals by the mint holder;
- `UniswapInspector.t.sol`: derives the pool from the Position Manager and
  factory rather than guessing an address;
- `SwapSimulation.t.sol`: simulates only the eventual L2 router call; and
- `InboxEnvelopeInspector.t.sol`: constructs the L1 retryable ticket and
  displays the message fields before final relay.

## Lessons

- A chain without an accessible RPC can still be reachable through its L1
  message ingress.
- Read the test harness before writing code: here it specifies both identity
  aliasing and the exact message fields that matter.
- A verified ABI matters as much as the contract address. Router V3 and
  SwapRouter02 use different tuple layouts.
- Separate three questions: where liquidity came from, how to trade against it
  and how to deliver the trade to a chain you cannot call directly.
- Filter logs at the node when possible. A `Transfer(from = 0)` query is much
  more useful than downloading every trade.
