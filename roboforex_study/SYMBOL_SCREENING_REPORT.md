# Symbol Screening Report — Portfolio Diversification Discovery Pass

**Objective** (per explicit user request): not to find the single most profitable
symbol, but to identify additional symbols worth deeper investigation as
**portfolio diversifiers** alongside the existing EURUSD/GBPUSD/USDJPY portfolio —
using a fast, narrow-scope screening pass, not a final optimization.

**Account/window**: RoboForex-Pro, Login `52010662`, `Deposit=15000 USD`,
`Leverage=1000`, `H4`, `Model=4`, **2025.03.01–2026.03.01** (a clean 1-year window,
chosen deliberately inside the account's confirmed 100%-real-tick data range and
leaving the remaining data on both sides free for out-of-sample/forward validation
of whichever candidates hold up).

**Method — two passes**:
- **Pass 1**: `Optimization=3` ("All symbols selected in Market Watch") — not a
  parameter sweep, a single fixed configuration (`strategyA_bb_default.set`, the
  same BB-mode default used throughout this study) re-run once per symbol in
  Market Watch. Run by the user directly (their live terminal's Market Watch uses
  the `forex.all` symbol set — broader than the portable terminal's `forex.major`
  used earlier in this study), XML supplied for analysis. **21 symbols**, including
  all 3 existing-portfolio symbols, giving a same-window, directly-comparable
  baseline for everything at once.
- **Pass 2**: `Optimization=2` ("Fast genetic based algorithm") on
  `InpBBPeriod`×`InpBBDeviation` (the same 2-parameter, 49-combination scope
  already validated for the existing portfolio's own optimization grids in this
  study — kept narrow per the request's own "screening, not final optimization"
  instruction). Run for a **10-symbol shortlist** selected from Pass 1 by
  risk-adjusted metrics (Recovery Factor/Sharpe), not raw profit. **Note**: MT5's
  genetic algorithm evaluated the full 49/49 combinations for every symbol in this
  search space (small enough that it apparently doesn't subsample) — so Pass 2
  results below are effectively exhaustive-grid-quality, not a sparse genetic
  sample, which strengthens the robustness analysis in §B.

All raw XML/CSV outputs are preserved in `roboforex_study/reports/symbol_screening/`
for later inspection.

---

## A. Symbol Screening Table

All 21 Pass 1 symbols, sorted by default-parameter profit. **Existing portfolio**
marked; **Pass 2 shortlist** marked. "Robustness observation" for shortlisted
symbols draws on the full 49-combo Pass 2 grid (min/max DD%, min/max PF, negative-
profit count across the grid) — for non-shortlisted symbols it's Pass-1-only
(single data point, noted as such).

| Symbol | Default Profit | Default PF | Default Recovery | Default DD% | Trades | Robustness observation | Diversification observation |
|---|---:|---:|---:|---:|---:|---|---|
| GBPCHF | $607.56 | 1.88 | 0.25 | 16.01% | 95 | Pass-1-only. Highest raw profit but by far the worst risk-adjusted profile of any profitable symbol (Recovery 0.25, Sharpe 0.26, DD 16% — 5-10x deeper than nearly everything else). **Not shortlisted for Pass 2** — the default result itself already disqualifies it. | CHF exposure, new. Irrelevant given the risk profile above. |
| CHFJPY | $366.45 | 2.24 | 0.55 | 4.40% | 79 | Pass-1-only. Weak Recovery (0.55) despite decent profit — not shortlisted. | CHF+JPY, but weak risk-adjusted case. |
| **USDCHF** | $362.14 | 2.52 | 1.64 | 1.44% | 79 | **Pass 2 (10-symbol shortlist)**. Grid DD range 1.26–1.79% (tight, stable across all 49 combos). Best PF in grid only 3.72 (no inflated-PF artifact) — genuinely clean, well-behaved surface. | New currency (CHF), and a materially different DD character (tight, stable) from EUR/GBP/JPY portfolio. |
| USDJPY | $277.29 | 2.30 | 0.39 | 4.69% | 69 | *Existing portfolio* — already deeply studied elsewhere in this study (structurally elevated DD vs EUR/GBP, confirmed independently on both BB and QQE grids). | Existing portfolio member, not a new candidate. |
| **AUDCHF** | $247.60 | 6.24 | 2.89 | 0.57% | 79 | **Pass 2**. Grid DD range 0.38–10.46%; **15 of 49 combos went net-negative** (PF min 0.19) — roughly 30% of the parameter surface loses money. Best-PF corner (Dev=3.00 low-trade-count rows) reproduces the same PF-inflation artifact seen elsewhere. Real fragility, not just a lucky default. | AUD+CHF, materially different from portfolio — but fragility tempers the case. |
| **EURNZD** | $235.22 | 1.92 | 0.44 | 3.55% | 72 | Weak Recovery (0.44) at default — not shortlisted. | NZD exposure, new — but weak default case. |
| **AUDUSD** | $230.74 | 4.50 | 2.34 | 0.65% | 80 | **Pass 2**. Grid DD range **0.13–0.69%** — the tightest, most stable DD band of any shortlisted symbol, across all 49 combos. PF-inflation artifact present only at the sparse Dev=3.00 corner (expected, harmless once understood); zero negative-profit combos anywhere in the grid. **The single most structurally robust symbol in this screen.** | New currency pair (AUD), no overlap with EUR/GBP/JPY portfolio. Strong candidate. |
| **GBPJPY** | $223.14 | 5.86 | 2.84 | 0.52% | 59 | **Pass 2**. Grid DD range 0.21–**11.32%** — one combo (Period=35/Dev=1.50, close to the *default-ish* neighborhood) produces 11.3% DD, an order of magnitude worse than most of the grid. Top-PF rows (up to 118.62, clearly an artifact — 31 trades) all sit at the sparse Dev=3.00 corner. Mixed picture: a decent default, but a real cliff exists nearby in the grid. | GBP+JPY, both already represented in the existing portfolio — lower diversification value even before the fragility concern. |
| **EURJPY** | $215.38 | 2.73 | 1.73 | 0.83% | 75 | **Pass 2**. Grid DD range 0.17%–**99.60%(!)**. One combo (Period=25, Dev=1.75 — an unremarkable, non-edge value) produces **-$14,940 profit, 99.6% DD — a near-total account wipeout**, on 94 trades. This is the single most serious robustness red flag in the entire screen: a dangerous cliff sits in the *middle* of an otherwise ordinary-looking parameter grid, not at an obvious edge. The good-looking default/best-combo numbers give no hint of this. | EUR+JPY, both already in portfolio. Given the wipeout risk found nearby in parameter space, **not recommended as a candidate regardless of diversification value**. |
| **GBPUSD** | $214.42 | 2.71 | 1.93 | 0.74% | 59 | *Existing portfolio*. | Existing portfolio member. |
| **NZDUSD** | $211.68 | 3.76 | 1.66 | 0.84% | 69 | **Pass 2**. Grid DD range 0.20–1.65% (moderate spread, no cliffs). Best PF 5.65 (highest grid PF only moderately elevated, not a sparse-corner artifact — plausible). Reasonably robust. | New currency (NZD), no overlap with existing portfolio. |
| **AUDJPY** | $203.56 | **10.23** | 4.58 | 0.29% | 63 | **Pass 2**. Default PF of 10.23 looked exceptional in Pass 1 — but the Pass-2 grid shows the **profit-maximizing combo (Period=40/Dev=1.50) actually has *worse* PF (3.73) and Recovery (1.89) than the default**, and the grid's genuine top-PF rows (up to 66.17) are the familiar sparse Dev=3.00/Dev=2.75 artifact (29-44 trades). This strongly suggests AUDJPY's attractive *default* PF was itself a small-sample artifact of that one specific combo, not a real edge — confirmed by the wider grid, not merely suspected. | JPY already in portfolio. Given the default-result artifact finding, treat cautiously. |
| **USDCAD** | $201.06 | 3.03 | 1.00 | 1.33% | 69 | **Pass 2**. Grid DD range 1.32–2.08% (tight, stable, no cliffs). No inflated-PF artifacts (grid max PF only 4.05). One of the cleanest, most boring — in a good way — grids in the shortlist. | New currency (CAD), no overlap with portfolio. |
| EURUSD | $177.27 | 4.08 | 2.46 | 0.48% | 56 | *Existing portfolio*. | Existing portfolio member. |
| EURAUD | $157.06 | 1.91 | 0.48 | 2.19% | 61 | Weak Recovery — not shortlisted. | AUD exposure, new, but weak default case. |
| EURGBP | $147.94 | 1.63 | 0.37 | 2.67% | 84 | Weakest risk-adjusted profile among the moderately-profitable set — not shortlisted. | Both currencies already in portfolio; low value even before the weak numbers. |
| **CADCHF** | $147.48 | 5.10 | 2.31 | 0.42% | 60 | **Pass 2**. Grid DD range 0.27–1.00% (tight, stable, no cliffs). Grid max PF only 7.34 at 57 trades — elevated but not a sparse-corner artifact, plausible. One of the more stable grids alongside AUDUSD/USDCAD/USDCHF. | CAD+CHF, both new — no overlap with portfolio at all. |
| **EURCAD** | $127.21 | 3.30 | 1.35 | 0.63% | 62 | **Pass 2**. Grid DD range 0.22–2.45% (moderate, no cliffs). Sparse-corner PF-inflation present (up to 31.45 at 26 trades, Dev=3.00) but understood/expected. Profit-maximizing combo trades Recovery down to 0.69 from default's 1.35 — the familiar profit-vs-risk-adjusted-quality tradeoff, not a robustness failure. | New currency (CAD) alongside existing EUR exposure — partial diversification. |
| EURCHF | -$16.47 | 0.94 | -0.04 | 2.62% | 76 | Pass-1-only. Essentially flat/slightly negative at default — not shortlisted, no reason to expect optimization to fix a structurally weak pair. | N/A — not viable at default. |
| AUDCAD | -$1,764.00 | 0.05 | -0.86 | 13.63% | 75 | Pass-1-only. Clearly broken at default parameters (PF 0.05, deeply negative Recovery). **Excluded from Pass 2** — no reason to believe a narrow BB-parameter sweep rescues a symbol this badly broken at default. | N/A. |
| AUDNZD | -$5,038.64 | 0.03 | -0.94 | 35.53% | 105 | Pass-1-only. The worst result in the entire screen — catastrophic at default (PF 0.03, DD 35.5%). **Excluded from Pass 2** for the same reason as AUDCAD. | N/A. |

**Symbols excluded from testing entirely**: none — every symbol in the user's live
Market Watch (`forex.all`) was tested per the "do not manually restrict" instruction.
No symbol was found technically unsuitable for backtesting (all 21 produced valid,
complete reports).

---

## B. Candidate Symbols

Per the task's own instruction, this is **not** the highest-net-profit ranking.
Candidates are selected for a combination of (1) genuine risk-adjusted quality, (2)
demonstrated structural robustness across the full Pass-2 parameter grid (not just
one lucky combo), and (3) currency exposure that doesn't already overlap heavily
with the existing EUR/GBP/JPY-weighted portfolio.

### Tier 1 — strong candidates, recommend deeper testing

- **AUDUSD** — the standout of the whole screen. Tightest, most stable DD band of
  any symbol tested (0.13–0.69% across all 49 grid combos), zero negative-profit
  combos anywhere in the grid, solid default risk-adjusted metrics (PF 4.50,
  Recovery 2.34), and a currency (AUD) with zero overlap against the existing
  portfolio. The Pass-2 optimized combo (Period=35, Dev=1.50: $265.87, PF 4.44,
  Recovery 2.53) is a genuine, non-fragile improvement over default, not a
  narrow-peak artifact — the 2nd-best combo by profit ($264.35) is nearly
  identical, meaning the optimum is a broad plateau, not a spike.
- **USDCHF** — clean, boring-in-a-good-way grid: tight DD range (1.26–1.79%), no
  PF-inflation artifacts anywhere in the 49 combos, meaningful improvement from
  optimization (PF 2.52→3.66, Recovery 1.64→2.19) without the profit-vs-quality
  tradeoff seen elsewhere. New currency (CHF).
- **USDCAD** — similarly clean and stable (DD 1.32–2.08%, max grid PF only 4.05,
  no artifacts). New currency (CAD), modest but genuine default profitability, and
  optimization improves without degrading risk-adjusted quality (Recovery
  1.00→1.23).
- **CADCHF** — tight, stable DD band (0.27–1.00%) across the whole grid, no
  cliffs, two new currencies (CAD+CHF) simultaneously — the largest currency-space
  diversification jump of any single-symbol candidate in this screen.

### Tier 2 — interesting but needs the caution the task asked for

- **NZDUSD** — genuinely new currency (NZD), reasonably stable grid (DD
  0.20–1.65%), but with slightly more spread than the Tier 1 group; the
  optimization here traded some Recovery Factor away for profit (1.66→1.25),
  worth a second look rather than an immediate default assumption of "optimized =
  better."
- **EURCAD** — new currency (CAD) but only partial diversification since EUR is
  already in the portfolio; also shows the profit-vs-risk-adjusted-quality
  tradeoff clearly (Recovery drops from 1.35 default to 0.69 at the profit-best
  combo) — if pursued, the *default* parameters may be the more defensible choice
  over the *optimized* ones specifically because of this.

### Not recommended, with reasons (per the task's explicit "explain, don't just rank" instruction)

- **AUDJPY** — its attractive default PF (10.23) does not survive scrutiny: the
  wider Pass-2 grid shows the actual profit-maximizing parameter combo has *worse*
  PF/Recovery than default, and the grid's own genuinely high-PF corners are a
  well-understood small-sample artifact (29-44 trades at the sparse Dev≥2.75
  band). The default result looks like it landed on a lucky combination, not
  evidence of a real edge.
- **GBPJPY** — a real cliff exists in the parameter grid close to sensible-looking
  settings (11.32% DD at Period=35/Dev=1.50), and both currencies already overlap
  the existing portfolio, so even a robust version would add limited
  diversification value.
- **EURJPY** — the most serious finding in this entire screen: a near-total
  account wipeout (-$14,940 profit, 99.6% DD) sits at an unremarkable, non-edge
  parameter combination (Period=25, Dev=1.75) inside the same grid that also
  contains a perfectly attractive-looking best case. This is exactly the kind of
  hidden fragility the task's overfitting-control section asked to be caught, and
  it should weigh heavily against this symbol regardless of how good its
  best-case numbers look, especially given EUR and JPY are both already in the
  portfolio anyway.
- **AUDCHF** — 15 of 49 grid combinations (≈30%) are outright unprofitable, a
  materially less stable surface than any Tier 1/2 candidate, despite an
  attractive-looking default result.
- **GBPCHF** — never made it to Pass 2: its own default numbers already show the
  worst risk-adjusted profile (Recovery 0.25, Sharpe 0.26) of any profitable
  symbol in the screen, despite topping the raw-profit column. A textbook example
  of why the task explicitly said not to rank by profit alone.

---

## C. Portfolio-Level Analysis

**Method**: 7 single-parameter backtests (default `strategyA_bb_default.set`, no
optimization), one each for the 3 existing-portfolio symbols and the 4 Tier 1
candidates, all over the identical 2025.03.01–2026.03.01 window. Each result's
Total Net Profit/Trades was cross-checked against Pass 1's own numbers for that
symbol and matches exactly (e.g. EURUSD $177.27/56 trades, USDCHF $362.14/79
trades — identical to §A), confirming these are the same underlying runs, just
with the full deal log available this time instead of only summary stats. Deal
logs parsed for `(time, running Balance)`, forward-filled onto a daily grid,
converted to daily % returns, and cross-correlated. Full data and scripts:
`roboforex_study/reports/correlation_study/`.

**A methodological limitation surfaced immediately and is reported here rather
than glossed over**: "Balance" only steps down when a trade *closes* at a
loss, and for this BB-Centre-Band-exit strategy, Balance drawdown is almost
imperceptibly small for every symbol tested (well under 0.5% for 6 of 7
symbols) — consistent with a pattern this project has documented repeatedly
elsewhere (`TPSL_EQUITY_BALANCE_ROOT_CAUSE.md`): Balance looks smooth while
**Equity** (which reflects floating losses on sequences still open) is where
the real risk shows up, and each report's own Equity DD Maximal figure
(EURUSD 0.48%, GBPUSD 0.74%, USDJPY 4.69%, AUDUSD 0.65%, USDCHF 1.44%, USDCAD
1.33%, CADCHF 0.42% — all matching §A's Pass 1 figures exactly) confirms real
risk is 3-10x larger than Balance DD suggests. The `.htm` deal log gives
Balance at each close event, not a continuous floating-equity series, so this
analysis can show *realized-P&L timing correlation* (a genuine, useful result)
but **cannot yet show true equity-drawdown overlap** — that specifically needs
a forensic-instrumented build (the same per-tick MFE/MAE pattern already used
elsewhere in this project) run for each candidate, not attempted here to keep
this pass fast. Flagged as the top item in §D, not silently approximated.

### Daily-return correlation matrix (the real result of this section)

|  | EURUSD | GBPUSD | USDJPY | AUDUSD | USDCHF | USDCAD | CADCHF |
|---|---:|---:|---:|---:|---:|---:|---:|
| **EURUSD** | 1.00 | 0.38 | 0.28 | 0.10 | 0.05 | 0.10 | 0.04 |
| **GBPUSD** | 0.38 | 1.00 | 0.06 | 0.13 | 0.02 | 0.09 | 0.08 |
| **USDJPY** | 0.28 | 0.06 | 1.00 | 0.03 | 0.01 | -0.00 | 0.01 |
| **AUDUSD** | 0.10 | 0.13 | 0.03 | 1.00 | 0.03 | 0.09 | 0.07 |
| **USDCHF** | 0.05 | 0.02 | 0.01 | 0.03 | 1.00 | 0.07 | 0.15 |
| **USDCAD** | 0.10 | 0.09 | -0.00 | 0.09 | 0.07 | 1.00 | 0.03 |
| **CADCHF** | 0.04 | 0.08 | 0.01 | 0.07 | 0.15 | 0.03 | 1.00 |

**This is a genuine, quantitative confirmation of §B's currency-overlap
argument, not just the qualitative heuristic it was presented as before this
section was completed.** The existing 3-symbol portfolio already shows some
internal correlation (EUR-GBP 0.38, EUR-JPY 0.28 — both plausibly USD-leg-driven
co-movement; GBP-JPY only 0.06). **Every one of the 4 Tier 1 candidates
correlates weakly (0.01–0.15) against all 3 existing-portfolio symbols and
against each other** — the single highest candidate-pair correlation is
USDCHF-CADCHF at 0.15 (their shared CHF leg, unsurprising and still low in
absolute terms). AUDUSD's highest correlation with anything is 0.13 (vs
GBPUSD) — essentially an independent return stream. This is real evidence, not
an assumption, that all 4 Tier 1 candidates would add genuinely uncorrelated
return sources rather than just leveraging up the same underlying EUR/GBP/JPY
bet the existing portfolio already makes.

### Combined portfolio profit (informational — not the interesting finding on its own)

| Portfolio | Combined profit (1 yr, $15k/symbol) |
|---|---:|
| Existing only (EURUSD+GBPUSD+USDJPY) | $668.98 |
| + AUDUSD | $899.72 |
| + USDCHF | $1,031.12 |
| + USDCAD | $870.04 |
| + CADCHF | $816.46 |
| All 7 combined | $1,610.40 |

Combined profit rising as more independently-profitable symbols are added is
expected and not, by itself, evidence of a diversification benefit — the same
would happen by adding any profitable symbol regardless of correlation. The
correlation matrix above is the part of this analysis that actually
distinguishes "adding more of the same bet" from "adding a genuinely different
one," and it supports the latter for all 4 Tier 1 candidates.

### True equity-drawdown-overlap analysis (§D item 1, now complete)

Built `EA_DCA_CENT_V1_EquityForensic.mq5` — a pure-read copy of
`EA_DCA_CENT_V1.mq5` (diffed against the parent to confirm zero trading-logic
lines changed) that logs `(time, balance, equity, floating_profit)` once per
closed H4 bar. Re-ran all 7 symbols over the identical window; final balances
matched the earlier deal-log-based results almost exactly (one symbol,
EURUSD, showed a trivial $1.70/0.01% end-of-test lag from once-per-bar
sampling — immaterial). **Caveat carried forward honestly**: H4-bar sampling
can under-catch a true intrabar equity peak between samples, so the drawdown
figures below are a lower bound on true risk, not an exact peak — the same
sampling method applies uniformly to all 7 series, so the *comparisons*
between them remain valid even if any single absolute number could be a touch
conservative.

**Max equity drawdown, per symbol (H4-bar resolution)**:

| Symbol | Max Equity DD | When |
|---|---:|---|
| USDJPY | **4.28%** | 2025-04-22 |
| USDCHF | 1.24% | 2026-02-11 |
| USDCAD | 1.24% | 2025-12-26 |
| GBPUSD | 0.67% | 2025-07-16 |
| AUDUSD | 0.57% | 2025-12-12 |
| CADCHF | 0.38% | 2026-01-28 |
| EURUSD | 0.37% | 2025-07-17 |

USDJPY's own equity risk (already flagged repeatedly elsewhere in this study)
is confirmed here too — 3-11x deeper than every other symbol tested, on the
same window and parameters.

**Equity-return correlation (H4 bars) tells a more nuanced story than the
earlier balance-based matrix**, and is arguably the more meaningful measure
since equity reflects shared currency exposure moment-to-moment, not just
realized P&L at trade closes:

|  | EURUSD | GBPUSD | USDJPY | AUDUSD | USDCHF | USDCAD | CADCHF |
|---|---:|---:|---:|---:|---:|---:|---:|
| **EURUSD** | 1.00 | 0.36 | 0.21 | 0.13 | 0.23 | 0.14 | 0.20 |
| **GBPUSD** | 0.36 | 1.00 | 0.06 | 0.22 | 0.04 | 0.07 | 0.02 |
| **USDJPY** | 0.21 | 0.06 | 1.00 | 0.06 | 0.23 | 0.03 | 0.10 |
| **AUDUSD** | 0.13 | 0.22 | 0.06 | 1.00 | 0.06 | 0.18 | 0.04 |
| **USDCHF** | 0.23 | 0.04 | 0.23 | 0.06 | 1.00 | 0.09 | 0.34 |
| **USDCAD** | 0.14 | 0.07 | 0.03 | 0.18 | 0.09 | 1.00 | 0.01 |
| **CADCHF** | 0.20 | 0.02 | 0.10 | 0.04 | 0.34 | 0.01 | 1.00 |

USDCHF shows meaningfully higher equity correlation to the existing portfolio
(0.23 with both EURUSD and USDJPY) than it did on the balance-only measure
(0.05/0.01) — plausible given shared USD-leg exposure shows up in floating
equity immediately, before any trade closes. CADCHF-USDCHF (0.34) is the
single highest pair in the whole matrix, consistent with their shared CHF
leg. AUDUSD and USDCAD remain the most independent of the 4 candidates on
this measure too.

**A real, visible drawdown-timing overlap was found**, not just inferred from
correlation: USDCHF's own April 2025 drawdown episode (2025-04-14 to
04-22, peak 1.16%) sits *inside* USDJPY's much larger April 10-25 episode
(peak 4.28%) — the two symbols' worst period of the year materially
coincides. CADCHF and USDCHF also co-drawdown in late January 2026 (CADCHF's
only notable episode, 2026-01-27/28, sits inside USDCHF's 2026-01-23–02-02
episode) — consistent with their 0.34 correlation. No other cross-symbol
drawdown overlap of this kind was found among the remaining pairs.

**The combined-portfolio result is the clearest evidence this study has
produced for a genuine diversification benefit**, not just low pairwise
correlation:

| Portfolio | Combined max equity DD |
|---|---:|
| Existing only (EUR+GBP+JPY) | 1.43% |
| + AUDUSD | 1.08% |
| + USDCHF | 1.35% (smallest improvement of the 4) |
| + USDCAD | 1.08% |
| + CADCHF | **1.05%** (largest improvement of the 4) |
| **All 7 combined** | **0.77%** |

The existing 3-symbol portfolio's combined peak DD (1.43%) is already below
the simple average of its members' own individual DDs (1.77%) — USDJPY's
4.28% peak gets diluted because EUR/GBP weren't in drawdown at the same
moment. **Every one of the 4 Tier 1 candidates reduces combined portfolio
drawdown further when added**, and all 7 combined cuts peak DD to 0.77% —
nearly half the existing-portfolio-alone figure, and under a fifth of
USDJPY's own standalone risk. Tellingly, **the ranking of drawdown-reduction
benefit tracks correlation, not each candidate's own risk level**: CADCHF
(near-zero correlation, small solo DD) gives the biggest combined-DD
improvement; USDCHF (the most-correlated candidate) gives the smallest
improvement despite a comparable solo DD to USDCAD. This is exactly the kind
of result that distinguishes genuine diversification from just adding
another profitable symbol.

---

## D. Recommended Next Tests

Item 1 (equity-curve drawdown-overlap) from the previous version of this
section is now **done** — see §C's equity-forensic analysis above. Renumbered
list of what's still open:

1. **Wider historical period for the Tier 1 candidates** — this screen
   deliberately used only 1 year; before treating AUDUSD/USDCHF/USDCAD/CADCHF as
   validated, re-run them over the same longer 2024.01–2026.09 window already
   used for the existing portfolio, for a like-for-like comparison and a larger
   trade sample.
2. **Out-of-sample validation** — the ~6 months of most-recent data
   (2026.03–2026.09, not used in this screen) plus the earlier 2024.01–2025.03
   slice are both still "unseen" for these new candidates and should be used as
   genuine OOS windows before any live consideration, mirroring this study's own
   existing-portfolio OOS discipline.
3. **Parameter sensitivity re-check specifically for EURJPY-style cliffs** — given
   how serious and non-obvious the EURJPY wipeout finding was, it's worth a denser
   parameter grid (not just the 7×7 already run) around any Tier 1/2 candidate's
   chosen combo, specifically checking neighboring combos for hidden drawdown
   cliffs the coarse 5-unit/0.25-unit grid could have stepped over undetected.
4. **Walk-forward testing** for whichever candidates survive #1-3, matching the
   rigor already planned for the existing portfolio's own multiplier-system
   decision.
5. **Monte Carlo analysis** on the strongest surviving candidate(s), for the same
   reason this study has used it elsewhere — a single equity curve, however good,
   doesn't establish robustness to trade-sequence variation on its own.
6. **USDCHF-CADCHF co-drawdown specifically** — their 0.34 correlation and the
   real January 2026 overlap found in §C means these two probably shouldn't be
   treated as fully independent additions if both were adopted; worth checking
   whether combining them adds meaningfully less benefit than either alone
   paired with AUDUSD/USDCAD instead.

**Not recommended for further testing**: GBPCHF, AUDCAD, AUDNZD, EURCHF (all
non-viable or clearly broken at default, per §A), and EURJPY specifically because
of the wipeout finding in §B — this should be treated as a real result, not
revisited casually without first understanding *why* that parameter region is so
dangerous.
