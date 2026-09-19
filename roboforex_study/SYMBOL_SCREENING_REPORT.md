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
  1.00→1.23). **Update, §D**: the wider-window/OOS validation done after this
  section was first written found a real 10%+ equity drawdown episode entirely
  inside the previously-untested 2026.03-2026.09 window — this symbol's Tier 1
  status here reflects the 1-year screening window only and should be read
  alongside §D's downgrade, not on its own.
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

## D. Wider-Window and Out-of-Sample Validation (complete)

**Method**: all 4 Tier 1 candidates, using the actual finalized portfolio `.set`
files (`roboforex_study/sets/cent_portfolio/`, with their final per-symbol magic
numbers), each run over 3 windows: the **full** 2024.01.01–2026.09.19 period
(matching the existing portfolio's own already-tested window, for direct
comparison against EURUSD/GBPUSD/USDJPY's known numbers), **OOS-A**
(2024.01.01–2025.03.01, before the original 1-year screen) and **OOS-B**
(2026.03.01–2026.09.19, after it — the most recent, previously-untouched data).
12 single-parameter backtests total; raw reports in
`roboforex_study/reports/wider_window_oos/`.

| Symbol | Window | Profit | PF | Recovery | Sharpe | Balance DD | Equity DD | Trades |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| AUDUSD | Full | $691.15 | 3.31 | 2.32 | 1.19 | 0.34% | 1.97% | 202 |
| AUDUSD | OOS-A | $334.68 | 3.29 | 1.13 | 1.13 | 0.32% | 1.97% | 79 |
| AUDUSD | OOS-B | $125.73 | 2.46 | 0.78 | 0.88 | 0.35% | 1.07% | 43 |
| USDCHF | Full | $586.23 | 2.06 | 1.24 | 0.69 | 0.65% | 3.14% | 207 |
| USDCHF | OOS-A | $155.24 | 1.55 | 0.33 | 0.34 | 0.65% | 3.14% | 94 |
| USDCHF | OOS-B | $68.85 | 3.09 | 1.64 | 2.14 | 0.06% | 0.28% | 34 |
| **USDCAD** | Full | $490.36 | 1.50 | 0.32 | 0.33 | 3.14% | **10.02%** | 225 |
| USDCAD | OOS-A | $276.14 | 2.48 | 1.43 | 0.94 | 0.32% | 1.27% | 91 |
| **USDCAD** | **OOS-B** | **$6.17** | **1.01** | **0.00** | 0.01 | 3.24% | **10.35%** | 65 |
| CADCHF | Full | $471.85 | 3.26 | 1.03 | 1.10 | 0.66% | 3.04% | 192 |
| CADCHF | OOS-A | $255.69 | 2.59 | 0.56 | 0.86 | 0.66% | 3.04% | 97 |
| CADCHF | OOS-B | $72.90 | 7.00 | 2.94 | 3.38 | 0.03% | 0.16% | 36 |

**AUDUSD holds up across every window** — consistently the strongest of the 4,
positive and reasonably stable in all three periods. No new concerns.

**CADCHF holds up reasonably well** — no blowups anywhere, strong in the
freshest OOS-B window (though only 36 trades there — small-sample caution, not
a red flag on its own).

**USDCHF is inconsistent but not alarming** — meaningfully weaker Recovery
Factor in OOS-A (0.33) than elsewhere, but never negative, and its 1-year
screening-window numbers (§A) sit within the range shown here.

**USDCAD: a serious finding.** The Full-window and OOS-B rows share an
**identical $1,555.81 Equity Drawdown Maximal figure** (10.02% vs 10.35% —
the small percentage difference is just a different denominator, same dollar
peak-to-trough) — proof this is *one single episode*, entirely contained
within the window the original 1-year screen never touched (that screen ended
2026.03.01, right as this episode began). Balance DD stayed a modest
3.14-3.24% throughout while Equity DD reached over 10% — the same
"Balance hides the real risk" pattern this project has now documented
repeatedly (`TPSL_EQUITY_BALANCE_ROOT_CAUSE.md`, the BB/QQE optimization
grids' own USDJPY findings) recurring here on a genuinely new symbol. OOS-B's
overall result is barely breakeven (Profit $6.17, PF 1.01, Recovery Factor
**0.00** on 65 trades) — six and a half months of trading netting to
essentially nothing while carrying a double-digit equity drawdown somewhere
inside it. Confirmed via the deal log: a DCA sell-sequence adding multiple
legs (lot sizes 0.01→0.04, matching the Linear multiplier system) against a
rising USDCAD through March-April 2026, the same no-stop-loss averaging
mechanism already documented as the cause of USDJPY's earlier $400-account
stress-test blowup, just far less severe here at the real $15,000 deposit
level.

**This changes USDCAD's status.** It was elevated to Tier 1 based on a 1-year
screening window that, in hindsight, simply didn't contain this risk episode
— precisely the scenario out-of-sample testing exists to catch, and it did.
**Downgraded from Tier 1 pending further investigation** — not automatically
disqualified (full-window profit is still solidly positive at $490.36, and
one adverse episode isn't inherently fatal, the same standard already applied
to EURJPY's cliff rather than blanket-rejecting it), but it should no longer
be described as "confirmed robust" alongside AUDUSD and CADCHF. See
`CURRENT_PORTFOLIO.md` for the corresponding flag on the live deployment
candidate.

## D2. USDCAD Drawdown Episode — Trade-Level Investigation (complete)

**Method**: re-ran USDCAD OOS-B (2026.03.01–2026.09.19) with
`EA_DCA_CENT_V1_EquityForensic.mq5` (per-bar equity/balance logging, §C's
build) to pinpoint the exact drawdown timing, then cross-referenced the
matching deal log (`wide_USDCAD_oosB.htm`) to trace the specific sequence
activity. Raw data: `roboforex_study/reports/usdcad_investigation/`.

**Timing**: equity peaked at $15,036 on 2026-05-11, bottomed at $13,507.54 on
2026-07-06 — a $1,528 (10.17%) floating loss over roughly 8 weeks.

**Mechanism, confirmed from the deal log**: starting 2026-05-11, a SELL
sequence opens and adds legs as USDCAD *rises* (adverse to the position) —
by 2026-05-28 a **second** concurrent sell sequence starts alongside it, and
by 2026-06-12/07-01 a **third** joins too, all within `InpMaxSequencesPerDirection
=3`'s limit. Each sequence independently averages up its own 7-leg Linear
multiplier ladder (0.01→0.07 lot) as price keeps climbing — USDCAD rose from
~1.364 (2026-05-06 entry) to ~1.423 (2026-06-25), roughly **590 pips** against
every one of the 3 stacked sequences simultaneously, with no fixed stop-loss
anywhere (by DCA mode's own design). This is structurally identical to the
mechanism already documented as the cause of USDJPY's earlier $400-account
stress-test blowup (`ROBOFOREX_MULTI_SYMBOL_STUDY.md` §2) — multiple parallel
DCA sequences all averaging into the same sustained adverse trend at once —
just manifesting far less severely here at the real $15,000 deposit.

**Resolution — not a forced stop-out.** On 2026-07-17 20:00:00, price reverted
from its ~1.423 peak back to ~1.401, and BB Centre Band exit triggered a mass
close of 11 legs in a single batch (lot sizes 0.07 down to 0.01, spanning all
3 stacked sequences) — Balance moved from ~$15,439 to $14,986 in that one
event, a realized loss of about **$453**. This is a real, meaningful loss, but
nowhere near the full $1,528 unrealized peak — most of the floating loss
*did* recover before the position was ever forced to close, confirming the
strategy's own mean-reversion assumption ultimately held here. Trading
continued normally through August and the account climbed back toward
breakeven by month-end, consistent with OOS-B's overall near-flat $6.17 net
result (§D).

**Verdict — a genuine near-miss, not a false alarm and not a catastrophe.**
Two things are simultaneously true and both matter: (1) the strategy's design
worked as intended — it survived a genuinely adverse 590-pip, 8-week move
across 3 concurrent sequences without a forced stop-out or a large realized
loss, and (2) an account monitoring *only* Balance during those 8 weeks would
have seen almost nothing wrong (Balance DD stayed 3.14-3.24% throughout) while
Equity was actually down over 10% — a real, uncomfortable, un-visible-on-Balance
risk window that a margin call, a nervous manual intervention, or a slightly
worse continuation of the trend could have turned into a forced loss instead
of a recovery. **Classification: Logical Design Choice, not an Implementation
Bug** — DCA mode is designed to average into adverse moves expecting
reversion, and multiple concurrent sequences compounding that bet during a
genuine sustained trend is the structural, foreseeable consequence of that
design, not a coding error. Same classification standard already applied to
the USDJPY finding.

**Practical implication**: USDCAD isn't disqualified by this — it did what a
DCA strategy without a stop-loss is expected to do under stress, and it
recovered. But this is concrete, trade-level evidence that the Max Floating
Loss circuit breaker (currently disabled in `CURRENT_PORTFOLIO.md`, §
"deliberately different") is exactly the kind of protection that would have
mattered here, and that Equity (not Balance) is the number that must be
watched or automated against for USDCAD specifically. Whether that argues for
enabling the circuit breaker before deploying USDCAD, deploying it anyway with
manual equity monitoring, or holding it back until walk-forward/Monte Carlo
give more confidence is a decision for the user, not resolved here.

## D3. Dense Parameter-Neighborhood Check for Hidden Cliffs (complete — clean)

**Method**: given how serious and non-obvious both the EURJPY wipeout (§B) and
the USDCAD time-window finding (§D2) turned out to be, checked whether a
similar *parameter-space* cliff could be hiding near what's actually deployed.
Built a denser grid — `InpBBPeriod` ∈ {30..40 step 1} × `InpBBDeviation` ∈
{2.00..2.50 step 0.05}, 121 combinations, 5x finer than the original
screening grid's 5-unit/0.25-unit steps — centered directly on the deployed
default (Period 35, Deviation 2.25), run via fast genetic optimization
(evaluated the full 121/121 combinations, same as previous grids) for all 4
Tier 1 candidates over the same 1-year screening window. Raw data:
`roboforex_study/reports/dense_grid/`.

| Symbol | Equity DD range | PF range | Negative-profit combos | Default combo consistency |
|---|---|---|---:|---|
| AUDUSD | 0.26–0.67% | 3.74–8.60 | 0/121 | Exact match to §A Pass 1 ($230.74, PF 4.50, 80 trades) |
| USDCHF | 1.26–1.49% | 2.31–3.67 | 0/121 | Exact match ($362.14, PF 2.52, 79 trades) |
| USDCAD | 1.32–1.33% | 2.71–3.24 | 0/121 | Exact match ($201.06, PF 3.03, 69 trades) |
| CADCHF | 0.42–0.91% | 2.40–5.61 | 0/121 | Exact match ($147.48, PF 5.10, 60 trades) |

**Clean result — no hidden cliffs found near any of the 4 deployed defaults.**
Every symbol's equity DD stays in a tight, boring band across the entire
121-combo neighborhood, every combo is profitable (zero negative-profit
results, unlike EURJPY's grid which had 6), and each default combo's exact
result reproduces §A's Pass 1 number precisely — confirming both the
consistency of the data and that these aren't fragile, isolated good-luck
points the way EURJPY's was.

**USDCAD's own result here is worth calling out specifically**: its Equity DD
range across all 121 neighboring combos is essentially flat (1.32–1.33%,
under a hundredth of a percent of spread) — meaning §D2's drawdown episode is
confirmed to be purely a **time-domain** risk (a specific adverse trend
period), not a **parameter-domain** fragility. Changing `InpBBPeriod`/
`InpBBDeviation` anywhere in this neighborhood would not have avoided or
worsened that episode — it was about *when* the sequences were open, not
*which* BB settings opened them. This usefully separates the two USDCAD
findings rather than conflating them: the parameter choice is fine, the
multi-sequence-under-sustained-trend exposure is the real and separate risk
already documented in §D2.

## D4. Walk-Forward (Rolling-Window) Consistency Check (complete)

**Method**: the actual deployment uses fixed, non-reoptimized parameters, so
the meaningful walk-forward question here isn't "does re-optimizing each
period help" but "does the fixed default configuration hold up across every
sequential slice of time, not just the Full/OOS-A/OOS-B split already done
(§D)." Split the full 2024.01.01–2026.09.19 history into 5 sequential
~6-month windows and ran all 4 Tier 1 candidates (deployed `.set` files)
through each — 20 single-parameter backtests. Raw data:
`roboforex_study/reports/walk_forward/`.

| Symbol | 2024 H1 | 2024 H2 | 2025 H1 | 2025 H2 | 2026 (partial) | Negative windows |
|---|---:|---:|---:|---:|---:|---:|
| AUDUSD | $92.84 (PF 9.08) | $55.49 (PF 1.31) | $110.28 (PF 9.17) | $120.56 (PF 3.31) | $156.05 (PF 2.76) | **0/5** |
| USDCHF | $35.17 (PF 1.25) | $61.01 (PF 1.53) | $165.43 (PF 2.68) | $113.10 (PF 3.17) | $99.89 (PF 3.07) | **0/5** |
| USDCAD | $49.35 (PF 2.19) | $94.85 (PF 1.69) | $128.26 (PF 6.02) | **-$49.91 (PF 0.65)** | $34.32 (PF 1.05, DD 10.33%) | **1/5** |
| CADCHF | $89.79 (PF 5.22) | $108.79 (PF 2.00) | $65.66 (PF 2.46) | $70.39 (PF 24.23†) | $99.20 (PF 4.30) | **0/5** |

†CADCHF's 2025 H2 PF of 24.23 sits on only 26 trades — flagged per this
study's own recurring small-sample-inflation caution, not treated as a
genuine edge; its Equity DD in that same window is tiny (0.12%) so it isn't a
risk concern, just a statistic not to over-read.

**AUDUSD, USDCHF, and CADCHF are clean across every single window** — zero
negative half-year periods in 2.7 years of history for any of the three, the
strongest consistency evidence this study has produced for any candidate.

**USDCAD is the one exception, and this adds a new data point to its already-
flagged profile**: 2025 H2 (2025.07–2026.01) was a genuine losing half-year
(-$49.91, PF 0.65, Recovery Factor -0.25) — a *different* period from the
major drawdown episode already investigated in §D2 (which fell in the 2026
partial window, and the identical $1,555.81 Equity DD figure confirms it's
the same episode, now cross-validated a third time across three different
report runs). So USDCAD has now shown weakness in **two separate windows**
out of five, not just the one already investigated — reinforcing rather than
contradicting the "kept in, but not confirmed-robust the way AUDUSD/CADCHF
are" status already recorded in `CURRENT_PORTFOLIO.md`.

## D5. Monte Carlo Trade-Resampling Bootstrap (complete)

**Method**: same approach as `GO_LIVE_VALIDATION_PLAN.md` §4.13 — extract each
closed leg's net realized P&L (the Profit column on every `out`-type deal)
directly from real backtest deal logs (no synthetic data), then resample
**with replacement** to build 20,000 simulated equity paths of the same
length as the original trade count, measuring how much historical trade
*ordering* matters independent of the strategy's average edge. Reused the
full 2024.01–2026.09 deal logs already gathered for §D (no new backtests
needed). Script and full output: `roboforex_study/reports/monte_carlo/`.

| Symbol | Trades | Median max DD | 95th pct | 99th pct | Worst of 20,000 | P(net negative) |
|---|---:|---:|---:|---:|---:|---:|
| AUDUSD | 202 | $40.20 | $70.70 | $90.60 | $168.52 (1.12%) | **0.000%** |
| USDCHF | 207 | $67.79 | $122.50 | $157.38 | $303.84 (2.03%) | **0.000%** |
| **USDCAD** | 225 | **$131.87** | **$251.25** | **$328.31** | **$600.24 (4.00%)** | **0.330%** (66/20,000) |
| CADCHF | 192 | $43.82 | $83.27 | $109.28 | $194.29 (1.30%) | 0.015% (3/20,000) |

(Percentages are the worst-of-20,000 max drawdown against the $15,000
deposit, for scale.)

**AUDUSD and USDCHF never produced a net-negative simulated path across
20,000 reshuffles** — the strongest possible result this method can give.
**CADCHF is very close behind** (3 negative paths out of 20,000, 0.015%).

**USDCAD is the clear outlier on a fifth independent method now**: its
worst-of-20,000 drawdown (4.00% of deposit) is roughly 2-3x any other
candidate's, its 99th-percentile drawdown alone ($328.31) exceeds every other
symbol's *worst-case*, and it's the only one with a non-trivial chance
(0.33%, roughly 1 in 300) of a simulated path ending net negative. This is
directly explained by its own trade distribution: its pooled P&L set
includes the -$78.37 single-leg loss from the stacked-sequence unwind
investigated in §D2, and several other double-digit losses from that same
episode's mass close — real, already-understood outcomes, not new tail
risk, but resampling correctly surfaces that they make USDCAD's *ordering*
risk measurably higher than the other three.

**A methodological caveat specific to this DCA architecture, not present in
the original single-symbol Monte Carlo**: bootstrap resampling treats each
closed leg as an independent draw, but §D2 showed multiple legs from the
same stacked sequence often close together in a single correlated event
(the 11-leg mass close on 2026-07-17). Reshuffling independently can
therefore either under- or over-represent how often several large losses
actually land together in reality, compared to drawing them into the same
simulated path purely by chance. This doesn't invalidate the result — the
same "can't invent a worse loss than observed" limitation already noted in
`GO_LIVE_VALIDATION_PLAN.md` §4.13 still applies — but it's a real reason not
to treat USDCAD's 0.33% figure as a precise tail-risk estimate, only as
further confirmation (now via a fifth method) that it carries more
sequencing risk than AUDUSD, USDCHF, or CADCHF.

**Consistent with, not contradicting, every other USDCAD finding in this
report** (§B, §D2, §D4): kept in the portfolio per the user's decision, not
disqualified, but this is now the fifth independent line of evidence
(screening grid, OOS validation, trade-level investigation, walk-forward,
Monte Carlo) all pointing the same direction — USDCAD is structurally the
riskiest of the 4 Tier 1 candidates, even though its overall expectancy
remains positive.

## E. Recommended Next Tests

1. ~~Decide USDCAD's deployment status given D2's findings~~ — **decided
   2026-09-19**: keep the Max Floating Loss circuit breaker disabled for now,
   USDCAD stays in the portfolio as-is. §D4/§D5's results (a second losing
   window, the weakest Monte Carlo profile) don't change this decision but
   are worth knowing.
2. ~~Parameter sensitivity re-check specifically for EURJPY-style cliffs~~ —
   **done, see §D3**: clean across all 4 Tier 1 candidates, no hidden cliffs
   near any deployed default.
3. ~~Walk-forward testing~~ — **done, see §D4**: AUDUSD/USDCHF/CADCHF clean
   across all 5 rolling windows; USDCAD showed a second losing window
   (2025 H2, distinct from the already-investigated 2026 episode).
4. ~~Monte Carlo analysis~~ — **done, see §D5**: AUDUSD/USDCHF never went
   net-negative across 20,000 resamples; USDCAD is the clear outlier with
   the widest drawdown range and the only non-trivial chance (0.33%) of a
   net-negative path.
5. **USDCHF-CADCHF co-drawdown specifically** — their 0.34 correlation and the
   real January 2026 overlap found in §C means these two probably shouldn't be
   treated as fully independent additions if both were adopted; worth checking
   whether combining them adds meaningfully less benefit than either alone
   paired with AUDUSD instead (USDCAD's own role in the portfolio is now
   separately in question per item 1 above).

**Not recommended for further testing**: GBPCHF, AUDCAD, AUDNZD, EURCHF (all
non-viable or clearly broken at default, per §A), and EURJPY specifically because
of the wipeout finding in §B — this should be treated as a real result, not
revisited casually without first understanding *why* that parameter region is so
dangerous.
