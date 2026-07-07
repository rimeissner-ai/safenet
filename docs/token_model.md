# Token Model

## Summary

Sentinel economics are governed by three levers: the **bond multiplier** $k$, the **arbitration rate** $\alpha$, and the **transaction rate** $\lambda$. The annualised return for a capital-constrained sentinel (the steady-state regime at meaningful volume) is:

$$\boxed{\text{APR (\%)} = \left[\frac{1}{mk} - 0.5\alpha(1-K)\right] \times \frac{52{,}560{,}000}{D}, \quad D = (1-\alpha)\,t_f + \alpha\,t_a}$$

where $m$ is the number of sentinels, $k$ is the bond-to-fee multiplier, $K$ is the fraction of bond returned to losers in arbitration, $\alpha$ is the arbitration rate, $t_f$ and $t_a$ are the bond lock-up times without and with arbitration (minutes). The $0.5\alpha$ factor assumes each side has equal probability of winning a disputed question. The $\times 100$ converts the annual return multiple into a percentage.

**Recommended parameters** — $m = 5$, $k = 2{,}000$, $K = 0$ (full slash), with fixed network parameters $\alpha = 0.01\%$, $t_f = 1$ min, $t_a = 10{,}080$ min (1 week):

$$D = 0.9999 \times 1 + 0.0001 \times 10{,}080 = 2.008 \text{ min}$$

$$R \approx \left[\frac{1}{10{,}000} - 0.5 \times 0.0001\right] \times b = 0.00005\,b \quad \text{(net per question)}$$

$$\text{APR}_{\text{ceiling}} = \frac{0.00005}{2.008} \times 525{,}600 \times 100 \approx \mathbf{1{,}309\%} \quad \text{(at 100\% utilization)}$$

The ceiling assumes capital is deployed 100% of the time. Realistic APR scales with network utilization $U$:

| Utilization | APR |
|---|---|
| 1% | ≈ **13%** |
| 5% | ≈ **65%** |
| 10% | ≈ **131%** |

A target of **5–15% APR** is achievable at **1–2% utilization**, which is a realistic early-network operating point. Full bond slashing ($K = 0$) maximises deterrence; $m = 5$ provides strong oracle coverage; $k = 2{,}000$ keeps the fee-income term $2\times$ above the arbitration drag term with a comfortable margin before the breakeven at $k = 4{,}000$.

During the early network phase — when transaction volume is too low for fee revenue alone to attract sentinel capital — staking rewards provide a **participation-based subsidy**: sentinels that meet an uptime/responsiveness threshold earn a share of the SAFE reward pool each period, independent of individual question outcomes. This mirrors the existing Validator reward model and decouples sentinel participation incentives from transaction volume during bootstrap. As volume grows the subsidy can be reduced and the fee-driven APR above becomes self-sustaining.

---

## Overview

SafeNet uses two distinct tokens with separate roles:

- **SAFE Token** — governance and signaling
- **Fee Token (e.g., USDC)** — fees and sentinel bonds

These are kept strictly separate by design.

---

## SAFE Token

The SAFE token is used for **validator and sentinel selection**. Staking SAFE signals commitment to the network and determines eligibility to participate as a validator or sentinel.

Key properties:

- **No direct protocol coupling** — SAFE staking has no on-chain effect on active validators or sentinels. There is no automatic slashing of SAFE, and no automatic adjustment of validator/sentinel sets based on stake changes.
- **Signaling only** — SAFE stake expresses intent and reputation, not control. Governance processes use it to curate the validator and sentinel sets off-chain.
- **Separation of concerns** — Because SAFE is not involved in the economic security of individual oracle decisions, its value and volatility do not directly affect protocol liveness or safety.

---

## Fees and Bonds

All economic activity in the SentinelOracle is denominated in a separate **fee token** (e.g., USDC). This token is used for:

- **Request fees** — paid by the proposer when submitting a transaction for oracle review.
- **Sentinel bonds** — posted by each sentinel when casting a vote (approve or deny).

### Bond Amount

The bond each sentinel must post is a fixed multiple of the request fee:

```
bondTarget = REQUEST_FEE × k
```

where `k` is the **bond multiplier**, a governance-controlled parameter. The bond is held in escrow during the voting window and returned (or slashed) upon resolution.

### Fee Reward Distribution

Not all sentinels earn the same reward. **Faster answers receive a higher share of the fee**, creating an incentive for sentinels to respond promptly.

Let:

- $i$ — position of a sentinel's answer in the approve or deny queue, starting at 1
- $b_i$ — bond posted by the sentinel at position $i$
- $m$ — number of sentinels that voted on the winning side

Each sentinel's **score** is:

$$s_i = \frac{b_i}{i}$$

The **total score** across all winning sentinels is:

$$S_T = \sum_{0 < i \le m} s_i$$

Each sentinel's **fee reward** is proportional to their score:

$$r_i = \frac{s_i}{S_T} \cdot \text{fee}$$

Only sentinels on the **winning side** receive a fee reward. Sentinels on the losing side in a disputed (frozen) request have their bond slashed.

### Resolution Outcomes

| Scenario | Outcome | Bond Return | Fee |
|---|---|---|---|
| Only approve votes | `RESOLVED_APPROVED` | Returned to all approvers | Distributed to approvers by score |
| Only deny votes | `RESOLVED_DENIED` | Returned to all deniers | Distributed to deniers by score |
| Both sides voted | `FROZEN` → arbitrated | Losing side slashed | Refunded to proposer |
| No votes | `TIMED_OUT` | Returned | Refunded to proposer |

---

## Return on Capital

### Variables

| Symbol | Meaning |
|---|---|
| $\rho$ | Return on investment (ROI / APR) |
| $r$ | Average fee reward on a non-arbitrated question |
| $b$ | Bond amount posted per question |
| $C$ | Total capital a sentinel has allocated to the protocol |
| $P$ | Probability of winning an arbitrated question (only relevant in the `FROZEN` path) |
| $K$ | Expected fraction of bond returned in arbitration (e.g. $1/k$ if one sentinel in $k$ is typically wrong and the full bond is returned to correct sentinels) |
| $\lambda$ | Transaction rate (questions per minute) |
| $\alpha$ | Arbitration rate (fraction of questions that become frozen) |
| $t_f$ | Bond lock-up time when no arbitration occurs (minutes) |
| $t_a$ | Bond lock-up time when arbitration occurs (minutes) |

### Average Fee Reward

With $m$ sentinels posting equal bonds $b$ and arriving in uniformly random order, the expected score of a sentinel at position $i$ is $b/i$. The expected fee reward for a single sentinel on a clean (non-arbitrated) question is:

$$r = \frac{1}{m} \sum_{i=1}^{m} \frac{b/i}{\sum_{j=1}^{m} b/j} \cdot \text{fee} = \frac{\text{fee}}{m}$$

So each sentinel earns $1/m$ of the fee on average. For $m = 5$ this is $20\%$.

### Expected Bond Lock-Up Period

Each bond is locked for $t_f$ minutes on a clean resolution, and $t_a$ minutes when the request goes to arbitration. The expected lock-up time per question is:

$$D = (1 - \alpha) \cdot t_f + \alpha \cdot t_a$$

### Expected Return per Bond

On a clean (non-arbitrated) question every participating sentinel is on the winning side by construction — bond loss is only possible in the `FROZEN` → arbitration path. Therefore $P$ only applies to arbitrated questions:

$$R = r \cdot (1 - \alpha) + b \cdot \alpha \cdot \bigl(K \cdot P - (1 - P)\bigr)$$

- The first term is the fee reward on clean questions; all bonds are returned in full.
- The second term covers arbitrated questions: a correct sentinel ($P$) recovers fraction $K$ of the bond; an incorrect sentinel ($1-P$) loses the full bond.

For the recommended parameters ($P = 0.5$ in arbitration) this becomes:

$$R = r \cdot (1 - \alpha) + b \cdot \alpha \cdot (0.5K - 0.5) = r \cdot (1 - \alpha) - 0.5 \cdot b \cdot \alpha \cdot (1 - K)$$

### Capital Regimes and ROI

The ROI depends on whether a sentinel has more capital than needed to cover all concurrent bonds, or is capital-constrained.

The total capital required to participate in every question simultaneously is:

$$C_{\text{all}} = \lambda \cdot b \cdot D$$

**Regime 1 — Excess capital ($C \ge C_{\text{all}}$)**

The sentinel can cover every question. ROI scales with the transaction rate and the total capital allocated:

$$\rho = \frac{\lambda \cdot R}{C}$$

**Regime 2 — Capital-constrained ($C < C_{\text{all}}$)**

The sentinel cannot cover all questions and their capital is always fully deployed. Crucially, ROI is now **independent of both the transaction rate and the amount of capital** — it depends only on the return per bond cycle and the average lock-up duration:

$$\rho = \frac{R}{b \cdot D}$$

This is an important property: a capital-constrained sentinel's yield is determined entirely by the bond economics and the arbitration regime, not by how busy the network is.

### Annualized Return (APR) — No Arbitration Baseline

In the simplest case ($\alpha = 0$, $m = 5$, $k = 100$), the bond is $b = k \cdot \text{fee}$, $r = \text{fee}/m$, and $D = t_f$. In the capital-constrained regime:

$$\rho = \frac{r}{b \cdot t_f} = \frac{\text{fee}/m}{k \cdot \text{fee} \cdot t_f} = \frac{1}{m \cdot k \cdot t_f}$$

With $t_f$ expressed as a fraction of a year ($525{,}600$ minutes), the APR for $m = 5$ is:

$$\text{APR} = \frac{525{,}600 \times 100}{m \cdot k \cdot t_f} = \frac{10{,}512{,}000}{k \cdot t_f}$$

#### Example: $m = 5$, $k = 100$, $t_f = 2$ minutes

**Scenario A — Maximum theoretical capacity ($U = 100\%$, $\alpha = 0$)**

Bond is instantly recycled, sentinel is always capital-constrained:

$$\text{APR} = \frac{10{,}512{,}000}{100 \times 2} = \mathbf{52{,}560\%}$$

**Scenario B — Realistic moderate flow ($U = 5\%$, $\alpha = 0$)**

Sentinel is in the excess-capital regime, active roughly 1.2 hours per day:

$$\text{APR} = \frac{10{,}512{,}000 \times 0.05}{100 \times 2} = \mathbf{2{,}628\%}$$

### Parameter Recommendation

The adjustable parameters are $m$ (number of sentinels), $k$ (bond-to-fee multiplier), and $K$ (bond recovery fraction for losers in arbitration). The fixed network parameters are:

| Parameter | Value |
|---|---|
| Arbitration rate $\alpha$ | $0.01\%$ ($1$ in $10{,}000$) |
| Lock-up without arbitration $t_f$ | $1$ min |
| Lock-up with arbitration $t_a$ | $10{,}080$ min (1 week) |
| Probability of winning arbitration $P$ | $50\%$ |

These give an effective lock-up of $D = 0.9999 \times 1 + 0.0001 \times 10{,}080 = 2.008$ min and a bond cycle rate of $525{,}600 / 2.008 \approx 261{,}750$ per year.

Since $P$ only applies in arbitration, substituting $P = 0.5$, $b = k \cdot \text{fee}$, and $r = \text{fee}/m$ (the average fee reward derived in the Fee Reward Distribution section) gives $r = b/(mk)$. Substituting into the expected return formula:

$$R = \frac{b}{mk}(1 - \alpha) + b \cdot \alpha \cdot (0.5K - 0.5)$$

$$R = b\left[\frac{1-\alpha}{mk} - 0.5\alpha(1-K)\right]$$

Dividing by $b \cdot D$ gives the per-minute return as a fraction of the bond; multiplying by $525{,}600$ converts to an annual multiple; multiplying by $100$ expresses the result as a percentage APR:

$$\text{APR} = \frac{R}{b \cdot D} \times 525{,}600 \times 100 = \left[\frac{1-\alpha}{mk} - 0.5\alpha(1-K)\right] \times \frac{52{,}560{,}000}{D}$$

Since $\alpha = 0.0001$ is small, $1 - \alpha \approx 1$, and substituting $D = 2.008$ min:

$$\text{APR} \approx \left[\frac{1}{mk} - 0.00005(1-K)\right] \times 26{,}175{,}000$$

**Breakeven condition** (APR = 0): the fee income term must exceed the arbitration drag term.

$$\frac{1}{mk} > 0.00005(1-K) \implies mk < \frac{20{,}000}{1-K}$$

For $K = 0$ the breakeven is $mk = 20{,}000$; any higher and returns turn negative.

**Effect of $K$:** Increasing $K$ (returning more bond to losers) raises the breakeven $mk$ proportionally, requiring larger bonds relative to fees to hit the same APR. It also reduces deterrence. Setting $K = 0$ (full slash) is simplest, maximally deterrent, and requires the smallest $k$ for a given APR target.

**Capital-constrained APR ceiling for $K = 0$** (theoretical maximum at 100% utilization):

| $m$ | $k$ | $mk$ | APR ceiling |
|---|---|---|---|
| 5 | 1,500 | 7,500 | 3,490% |
| 5 | 2,000 | 10,000 | 1,309% |
| 5 | 2,500 | 12,500 | 785% |
| 5 | 3,000 | 15,000 | 436% |
| 10 | 1,000 | 10,000 | 1,309% |
| 10 | 1,250 | 12,500 | 785% |

These figures are theoretical ceilings, not operational targets. They assume every sentinel's bond is actively deployed 100% of the time. In practice the network starts with low request volume, so sentinels hold idle capital between requests. The **effective APR scales linearly with utilization** $U$ (fraction of time capital is actively bonded):

$$\text{APR}_{\text{effective}} \approx U \times \text{APR}_{\text{ceiling}}$$

**Realistic APR for $m = 5$, $k = 2{,}000$, $K = 0$:**

| Utilization $U$ | APR |
|---|---|
| 1% | ≈ 13% |
| 5% | ≈ 65% |
| 10% | ≈ 131% |

A target of **5–15% APR** is achievable at 1–2% utilization with these parameters, which is a realistic early-network operating point.

**Recommendation: $m = 5$, $k = 2{,}000$, $K = 0$**

- $m = 5$ provides strong oracle coverage with a reasonable capital requirement per sentinel.
- $k = 2{,}000$ sits well below the breakeven at $mk = 20{,}000$ ($k = 4{,}000$ for $m = 5$), providing a healthy margin.
- $K = 0$ (full slash) maximises arbitration deterrence and keeps the model simple.
- At early-network utilization (1–2%), this yields **13–26% APR** — sufficient to attract capital without unsustainable inflation.

### Annualized Return (APR) — With Arbitration

Substituting the full expressions for $R$ and $D$ into the capital-constrained ROI formula, with $P = 0.5$ in arbitration:

$$\rho = \frac{(1-\alpha)/(mk) - 0.5\alpha(1-K)}{D}$$

$$\text{APR}_{\text{arb}} = \rho \times 525{,}600 \times 100$$

#### Recommended parameters: $m = 5$, $k = 2{,}000$, $K = 0$, $t_f = 1$ min, $\alpha = 0.01\%$, $t_a = 10{,}080$ min

$$r = \frac{\text{fee}}{5} = \frac{b}{10{,}000}$$

$$D = 0.9999 \times 1 + 0.0001 \times 10{,}080 = 2.008 \text{ min}$$

$$R = \frac{b}{10{,}000} \times 0.9999 - 0.5 \times b \times 0.0001 \times 1 = 0.00009999b - 0.00005b = 0.00005b$$

$$\rho = \frac{0.00005b}{b \times 2.008} = \frac{0.00005}{2.008} \approx 0.0000249 \text{ per minute}$$

$$\text{APR}_{\text{arb}} = 0.0000249 \times 525{,}600 \times 100 \approx \mathbf{1{,}309\%}$$

This is the **capital-constrained ceiling** — the return per unit of bonded capital if that capital is deployed 100% of the time. It is not a realistic operational target; actual returns depend on how often requests arrive relative to how much capital is bonded.

At 1% utilization the effective APR is ≈ **13%**; at 5% utilization ≈ **65%**. The staking subsidy (see below) provides a utilization-independent floor, decoupling early-network participation from request volume.

The arbitration drag ($0.00005b$ per question) is exactly equal in magnitude to the fee income ($b/10{,}000$) at the breakeven point $k = 4{,}000$. At $k = 2{,}000$ the fee income is $2\times$ the drag, leaving a net gain of $0.00005b$ per question — half the gross fee income. Raising $\alpha$, $t_a$, or lowering $k$ all shrink this margin; the parameter recommendation provides a comfortable operating point.

---

## Self-Balancing Economic Feedback Loop

The fee and bond structure creates an automated feedback loop between data quality and sentinel profitability:

1. **Low capital / low quality.** If sentinels withdraw capital, $m$ falls (e.g., only 2 sentinels answer a question).

2. **Spike in yield.** With fewer sentinels sharing the fee, each earns a larger slice — averaging $50\%$ of the fee instead of $20\%$, roughly doubling the effective APR.

3. **Capital attraction.** The higher yield incentivizes sentinels to inject more capital (or compound earnings) to capture more slots.

4. **Equilibrium restored.** Capital flows back in until $m$ returns to 5, maximizing question quality and stabilizing yield back to baseline.

This means the protocol self-corrects: undercapitalization is expensive for the network but immediately profitable for participating sentinels, which corrects the imbalance without any governance intervention.

---

## Staking Subsidies for Sentinel Rewards

### Context: SafeNet Staking

SafeNet Validators stake SAFE tokens and earn SAFE rewards each two-week period. The reward pool is approximately 4,500,000 SAFE per period, distributed proportionally to time-weighted stake and conditional on a Validator meeting a 75% participation threshold. Delegators may also stake toward a Validator and earn 95% of the rewards generated by their delegated stake (5% commission goes to the Validator).

Critically, Beta staking rewards are currently **subsidized** — they are not funded by transaction fees but by the Safe Ecosystem Foundation under a SafeDAO-approved mandate. Long-term, the intent is for transaction fees to fund rewards. This creates a window during early network growth where the subsidy can be redirected or extended to also support sentinel economics.

Because Validators and Sentinels are operated by the same set of node operators, SAFE staking rewards are a natural mechanism to subsidize sentinel participation during the period when transaction volume — and therefore fee revenue — is too low to make sentinel bonding independently attractive.

### The Bootstrap Problem

At low $\lambda$ (transaction rate), a sentinel in the excess-capital regime earns:

$$\rho = \frac{\lambda \cdot R}{C}$$

If $\lambda$ is near zero, $\rho \approx 0$ regardless of $R$ and $C$. No rational sentinel will lock up capital for near-zero yield. Without sentinels, oracle quality collapses. This is the classic two-sided bootstrapping problem.

A staking subsidy decouples participation incentives from transaction volume by adding a floor to sentinel returns independent of $\lambda$.

### Subsidy Design Options

There are two primary approaches, with meaningfully different incentive properties.

#### Option 1 — Participation-Based Subsidy

Sentinels earn a fixed SAFE subsidy per reward period based solely on **whether they are registered, bonded, and responsive** — regardless of whether individual questions were arbitrated or their vote was correct.

**Mechanics:** At the end of each reward period, the subsidy pool is divided equally (or stake-weighted) among sentinels that met an uptime/responsiveness threshold, mirroring the existing Validator participation model.

**Properties:**
- Simple to implement and audit — no per-question outcome tracking needed.
- Predictable income for sentinels, making capital planning easier.
- Subsidizes the full cost of capital lock-up, including arbitration lock-up time.
- Does not penalize sentinels for honest disagreement that leads to arbitration.

**Tradeoff:** Because the subsidy is independent of correctness, it does not directly incentivize accuracy. A sentinel that votes randomly still collects the subsidy. The fee/bond mechanism provides the accuracy incentive, but the subsidy dilutes it at low volume. This is acceptable as a bootstrap measure but should not be the permanent model.

#### Option 2 — Performance-Based Subsidy (Correct Decisions Only)

Sentinels earn a SAFE subsidy only for questions where they **voted on the winning side** (i.e., consistent with the final resolution, excluding arbitrated disputes where the fee is refunded).

**Mechanics:** Each clean resolution records which sentinels voted correctly. At period end, a subsidy pool is allocated proportionally to correct-vote counts (optionally weighted by position score, consistent with the fee reward formula).

**Properties:**
- Directly rewards accurate, timely responses — the subsidy reinforces the same behaviour as the fee mechanism.
- Sentinels who frequently end up on the losing side or trigger arbitration receive less subsidy, creating a natural quality filter.
- More resistant to free-riding: a passive or randomly voting sentinel earns materially less.

**Tradeoff:** Requires per-question outcome tracking and a distribution mechanism that can handle many small payouts. Sentinels bear more income volatility, especially at low volume where a single arbitrated question can eliminate most subsidy earnings for a period. This may actually deter participation at very low volumes — the opposite of the intent.

#### Option 3 — Hybrid: Participation Floor + Performance Bonus

A two-tier structure combines both:

- A **base subsidy** paid for participation (meeting uptime/responsiveness thresholds), covering baseline capital costs.
- A **performance bonus** paid per correct decision, scaling with volume and accuracy.

As transaction volume grows, the performance bonus becomes a larger share of total sentinel income and the base subsidy can be reduced or phased out, eventually transitioning to a pure fee-driven model.

### Relationship to Existing Staking Rewards

The subsidy does not need to be a separate mechanism. It can be implemented as:

1. **Validator commission routing** — Validators/Sentinels that also operate oracle nodes could receive a higher commission rate or a separate reward multiplier funded from the existing staking pool, conditional on oracle participation. This requires no new token contract.

2. **Dedicated sentinel reward pool** — A separate SAFE allocation (governed by SafeDAO) distributed exclusively to active sentinels, independent of the Validator staking contract. Cleaner accounting but requires governance approval and a new distribution contract.

3. **Fee token top-up** — Rather than SAFE, the subsidy is paid in the fee token (e.g., USDC) from a treasury, injected as synthetic fees into the oracle. From the sentinel's perspective this is indistinguishable from real transaction fees, preserving the clean separation between SAFE (signaling) and the fee token (economic security).

### Summary

| Option | Simplicity | Accuracy incentive | Volatility for sentinels | Best suited for |
|---|---|---|---|---|
| Participation-based | High | Low | Low | Very early stage, near-zero volume |
| Performance-based | Medium | High | High | Low-but-nonzero volume |
| Hybrid | Medium | Medium–High | Medium | Gradual growth phase |

The recommended approach for the initial launch period is a **participation-based subsidy** to ensure sentinel capital is present from day one, transitioning toward a hybrid model as transaction volume grows and the performance signal becomes meaningful.
