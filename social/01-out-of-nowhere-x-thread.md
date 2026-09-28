# X thread draft — Wintermute Alpha Challenge 2026, Case 01

## Post 1/7

Wintermute Alpha Challenge 2026, case 01: “Out of Nowhere” (25 pts).

A ~$1.5M USDC transfer reaches Ethereum. Which source-chain transaction triggered it?

The method: use the bridge event as a cross-chain primary key. 👇

## Post 2/7

1/ Open the Ethereum transaction and scroll to **Transaction Receipt Event Logs**.

You will see a USDC `Transfer`, then Allbridge's `Received` event. The transfer
describes the final movement; `Received` contains the metadata needed to trace its origin.

## Post 3/7

2/ Decode `Received`:

- `source = 0x53544b5a` → ASCII `STKZ` → Stacks;
- copy `lockId` from **Topic 2**: it is an indexed event field.


## Post 4/7

3/ Allbridge's published contract list gives the historical Stacks contract:

`SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.bridge`

Hiro shows thousands of `lock` and `unlock` calls. Do not scroll manually: the
unique ID makes this an API-query problem.

## Post 5/7

4/ Prompt for Codex:

> Write Python to page Hiro's API (`limit=50`), keep
> `function_name == "lock"`, compare decoded `lock-id` to a CLI argument, and
> print matching tx + args. No hardcoded answer.

`lock` starts at source; `unlock` receives an incoming transfer.

## Post 6/7

5/ Run:

```bash
python3 scripts/find_stacks_lock.py 0x0159fa4cd496a40b6531521bb9138a06
```

Output:

`0x36f2d5c245d08de980d0d23e4bd23b088312ce9e4b9845b4fd71930f52aab8fc`

Open it in Hiro. It is a candidate until its fields check out.

## Post 7/7

6/ Verify: same `lockId`; recipient equals the Ethereum address after 32-byte padding;
`0x45544800` = `ETH`; and 1.5M USDC locked vs. 1.4985M received (a 0.1% fee).

Then `python3 alpha.py check 01` → 25/25. Use operation IDs, not value or time, as the primary key.
