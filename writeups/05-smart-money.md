# Smart Money — attributing an on-chain fundraise

> Status: solved locally (`100/100`).

## Objective

Attribute two historical fundraising wallets and two entities associated with
them. The task is not to guess a name from a transfer size. Wallet labels are
rare, fundraise wallets become treasuries, and one public funding announcement
can contain many investors.

The four requested answers are:

```text
protocol_one = C3 Protocol
investor_one = Node Capital
protocol_two = Aligned Layer
company = Bridge
```

## 1. Treat the two wallet questions separately

The first pair is:

```text
Fundraise / treasury clue: 0xAf0970A06BD17AD57f63d633be7f7039EB69Dc95
Unknown VC wallet:           0xC29Af06142138F893e3f1C1D11Aa98C3313B8C1f
```

The second pair is:

```text
Fresh recipient:  0xe53ec250fDF41e52d22fEF1f76DeE92A9377AC8f
Large-volume sender: 0x4c2c0F0bB2631B02aC9299C59690914ee7A200B8
```

Do not total the lifetime activity of either wallet. The first wallet also
moves funds through exchanges and later treasury operations. Those transfers
are not automatically part of a single raise.

## 2. Identify the first protocol, then constrain the investor

Open `0xAf09...` on Etherscan and inspect the early, time-localised stablecoin
inflows. They are a lead to a historical C3 fundraise, not a proof that every
later transfer belongs to it. A contemporary announcement identifies the
project as **C3 Protocol** and reports a $3.6m round with a list of backers.

That announcement alone cannot identify `0xC29...`: it lists several VCs.

### The differentiating on-chain clue

Open `0xC29...` and inspect its ETHFI history. It receives a large ETHFI
allocation through the ether.fi investor-distribution/custody route:

```text
ether.fi Investors → Anchorage → 0xC29...
```

This is materially different from a market purchase. It places the recipient
in ether.fi's investor set. ether.fi's allocation documentation separately
describes an investor allocation with vesting.

Now intersect the two public investor sets:

```text
C3 investors ∩ ether.fi investors = {Node Capital, Arrington Capital}
```

Finally, rule out Arrington: its wallet is publicly tagged and is not
`0xC29...`. The remaining candidate is **Node Capital**.

This is a constraint-based attribution, not a claim that a particular ETHFI
amount reveals an individual cheque size:

```text
0xC29... is an ether.fi investor
∩ investor in C3
∩ not the tagged Arrington wallet
= Node Capital
```

## 3. Attribute the second fundraise and the high-volume entity

For `0xe53e...`, inspect the first concentrated funding window rather than its
later balance. It is a fresh address receiving approximately $20m from several
sources. This matches the announced $20m Series A for **Aligned Layer**.

One incoming counterparty is `0x4c2c...`. Its transaction history has
multi-billion-dollar volume; address research and the entity's public material
identify the company behind it as **Bridge**. The answer is the company name,
not a protocol or the name of a related team.

## 4. Verification

Save the answers in `challenges/05-smart-money/answer.txt` and run:

```bash
python3 alpha.py check 05
```

The local checker reports `100/100`.

## Reusable method

1. Use early, bounded transaction windows; do not sum a wallet's entire life.
2. Use the chain to classify a flow: investor allocation, exchange movement,
   custody distribution or market trade.
3. Use contemporaneous fundraising disclosures to produce candidate sets.
4. Seek an independent on-chain relationship that narrows the set.
5. State exactly what each piece proves and what it does not.

## References

- [C3's $3.6m fundraising announcement](https://www.globenewswire.com/news-release/2021/11/22/2339278/0/en/c3-protocol-raises-3-6m-for-cross-margining-layer-that-reimagines-collateral-management-across-blockchains-led-by-arrington-capital-and-jump-capital.html)
- [Node Capital: “Our Investment in C3 Protocol”](https://node.capital/blog/combine-conquer/)
- [ether.fi ETHFI allocation documentation](https://etherfi.gitbook.io/gov/ethfi-allocations)
- [ether.fi's 2023 fundraising announcement](https://www.prnewswire.com/news-releases/etherfi-completes-usd-5-3-million-funding-round-co-led-by-niv-and-chapter-one-launches-liquid-staking-platform-301758981.html)
