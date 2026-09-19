# RoboForex Multi-Symbol Study — DCA CENT V1

**Status**: Phase 1 (login/data verification + Strategy A/B individual baselines, all
3 symbols) complete. Phase 2 (BB Period × Deviation optimization grid, all 3 symbols)
complete. Phase 3 (QQE Oversold/Overbought optimization grid, all 3 symbols) complete.
The QQE SF/WP multiplier grid (indicator-internal smoothing constants, not the
Oversold/Overbought signal levels) is explicitly deprioritized for now per user
direction — the levels sweep was the one that mattered; revisit only if asked.

**Correction on headless optimization**: an earlier note in `GO_LIVE_VALIDATION_PLAN.md`
claimed headless `Optimization=` mode writes results in a format "awkward to parse back
out headlessly," recommending the user run optimizations via the GUI instead. Retested
this directly (2026-09-19): headless optimization runs **do** auto-write a clean,
structured `<Report>.xml` (Excel-XML format) with one row per parameter combination and
columns for Profit/Profit Factor/Recovery Factor/Sharpe/Equity DD%/Trades/the swept
parameters — fully parseable. That earlier note was wrong (or referred to a since-fixed
limitation); headless optimization is now the primary method for this study's grids.

**Scope note**: per explicit user direction, this study targets **3 symbols** (not the
originally-proposed 10) on the **RoboForex** account — the actual go-live cent-account
broker — using **plain symbol names with no `c` suffix** (confirmed: `EURUSDc`/`GBPUSDc`
do not exist on this account; `EURUSD`/`GBPUSD`/`USDJPY` do).

---

## 0. Environment setup (prerequisite work, this session)

- RoboForex terminal (`C:\RoboForex MT5 Terminal`) had a **stale, pre-TP/SL copy** of
  `DCA_EA.mq5`/`EA_DCA_CENT_V1.mq5` in its `MQL5\Experts\EA-DCA-V1.0\` folder (not a
  symlink, unlike the FTMO terminal — a plain, manually-placed snapshot last updated
  before this session's TP/SL work). Refreshed from the repo and recompiled; 0
  errors/0 warnings.
- Found and fixed a real, previously-undocumented indicator-resolution gap: `iCustom()`
  with a bare name resolves against the **root** of `MQL5\Indicators\`, not the
  `EA-DCA-V1.0` subfolder. Both terminals keep a second, separate root-level copy of
  `QMP Filter`/`QQE Adv`/`MACD_Platinum` (space-containing names matching the exact
  `iCustom()` call strings) that is **not** kept in sync by the repo symlink. Found
  FTMO's root-level `QQE Adv.mq5` had drifted (different default `input` values,
  benign only because the EA always overrides them explicitly). Fixed on both
  terminals; documented in `CLAUDE.md`.
- Account: `Login=52010662`, `Server=RoboForex-Pro`, `Company=RoboForex Ltd`,
  `Currency=USD`, native leverage `1:1000` (per the account's own `ACCOUNT_LEVERAGE`,
  confirmed via the earlier `CheckCentSpec.mq5` diagnostic).

---

## 1. Symbol/data verification (Task per §2 of the request)

| Symbol | History Quality | Bars requested (2024.01.01-2026.09.19, H4) | Bars actually simulated | Real-data coverage |
|---|---|---:|---:|---|
| EURUSD | 100% real ticks | 4218 | **4218** (full) | Clean, full range |
| GBPUSD | 99% real ticks | 4218 | **4218** (full) | Clean, full range |
| USDJPY | 99% real ticks | 4218 | **924** (BB) / **504** (QQE) | Raw tick files present on disk for the full range (verified: `Bases\RoboForex-Pro\ticks\USDJPY\*.tkc`, no gaps, 2024.01-2026.09 complete) — the short bar count is **not a data-availability problem** |

**USDJPY's short bar count is explained by a genuine account blowup, not missing data**
— see §2.

---

## 2. CRITICAL FINDING — USDJPY blows a $400 account under both strategies with default parameters

Both Strategy A and Strategy B runs on USDJPY, at the same `$400` starting deposit used
for EURUSD/GBPUSD (matching this project's own `GO_LIVE_VALIDATION_PLAN.md` §5.4
precedent), hit a **broker-side margin Stop Out** and were forcibly liquidated:

| | Strategy A (BB) | Strategy B (QQE) |
|---|---|---|
| Stop-out date | 2024.08.05 | 2024.04.29 |
| Time to blow up | ~7 months | ~4 months |
| Stop-out level | `so -413.73%` | `so -619.74%` |
| Final balance | **-$45.51** (negative) | **-$117.75** (negative) |
| Reported "Total Net Profit" | -$445.51 | -$517.75 |
| Reported Profit Factor | 0.49 | 0.29 |

Confirmed directly from the deal log's own `so <equity%>` comment on the forced-closure
deals (MT5's standard stop-out marker), not inferred. Both re-run once to confirm
reproducibility — identical results both times, ruling out a one-off tick-cache
artifact (see `CLAUDE.md`'s documented cache-instability caveat, which does not apply
here since the numbers are stable on repeat).

**This is not a data bug — it is the EA's own DCA position sizing doing exactly what
it's configured to do, on a symbol/parameter combination it cannot survive at this
capital level.** Both `EA_DCA_CENT_V1_baseline.set`-derived configs use
`InpInitialLot=0.01`, `InpLotSizeMode=LOT_FIXED`, `InpMultiplierSystem=Linear`
(1,2,3,4,5,6,7×), uncapped-in-practice `InpMaxSequencesPerDirection=3`/
`InpMaxTradesPerSequence=0` — the same sizing that comfortably survived on
EURUSD/GBPUSD over the full 2.7-year window. USDJPY's much larger pip-value-per-lot at
this account's native leverage, combined with a DCA sequence that kept adding against
an adverse move with no fixed stop-loss (by design — DCA mode has none), produced a
sequence whose cumulative exposure exceeded what $400 of margin could sustain.

**This is exactly the kind of capital-adequacy risk this study's Objective #5 and
Critical Rule #7 ("do not hide poor results") exist to surface**, and is significant
new evidence for the eventual capital-requirement analysis (§11 of the request): the
required initial deposit is not just symbol-dependent in a minor way — for USDJPY
specifically, under these default parameters, $400 is **not viable at all**, not "less
optimal."

## 3. EURUSD / GBPUSD baselines (clean, full-range, both strategies)

| | EURUSD BB | EURUSD QQE | GBPUSD BB | GBPUSD QQE |
|---|---:|---:|---:|---:|
| Net Profit | $550.53 | $1,195.98 | $571.28 | $1,329.52 |
| Profit Factor | 3.78 | 3.92 | 2.22 | 3.21 |
| Total Trades | 173 | 315 | 185 | 325 |
| Ending Balance | $950.53 | $1,595.98 | $971.28 | $1,729.52 |
| History Quality | 100% | 100% | 99% | 99% |

Both symbols, both strategies, comfortably survived the full 2.7-year window at $400
starting deposit with no stop-out and strong risk-adjusted returns on this initial
pass. QQE-mode shows notably higher trade count and net profit than BB-mode on both
symbols in this unoptimized, default-parameter comparison — not yet meaningful beyond
"worth carrying both strategies into the optimization phase," per this study's own
anti-cherry-picking discipline (§6 of the request).

## 4. Resolved — re-baselined at the real funded deposit ($15,000)

The user reported the RoboForex account (`52010662`) has actually been funded: live
MT5 client shows Balance=Equity=**15,000**, Free Margin=150,000 (as displayed — this
project's own earlier RoboForex cent-mechanics finding, `GO_LIVE_VALIDATION_PLAN.md`
§5.3, established that contract size/margin are not rescaled on this account type,
only the balance display is; the correct move for backtesting is to match the
Tester's `Deposit=` to the account's own native displayed units directly, which is
what following does — not to guess a real-dollar equivalent).

Re-ran all 6 baselines at `Deposit=15000` (same `.set`s, same window, same account/
symbols). **This changes the picture substantially**:

| | EURUSD BB | EURUSD QQE | GBPUSD BB | GBPUSD QQE | USDJPY BB | USDJPY QQE |
|---|---:|---:|---:|---:|---:|---:|
| Net Profit | $550.53 | $1,195.98 | $571.28 | $1,329.52 | **$2,233.25** | **$5,051.87** |
| Profit Factor | 3.78 | 3.92 | 2.22 | 3.21 | 2.36 | 2.86 |
| Total Trades | 173 | 315 | 185 | 325 | 238 | 396 |
| Balance DD Max | $46.02 (0.30%) | $46.02 (0.29%) | $61.94 (0.40%) | $58.48 (0.36%) | $585.80 (3.61%) | $694.73 (4.20%) |
| **Equity DD Max** | $220.58 (1.45%) | $288.11 (1.83%) | $411.13 (2.71%) | $469.77 (2.88%) | **$2,843.33 (18.42%)** | **$3,409.63 (20.33%)** |
| Ending Balance | $15,550.53 | $16,195.98 | $15,571.28 | $16,329.52 | $17,233.25 | $20,051.87 |
| Stop-out? | No | No | No | No | **No** (survived full range) | **No** (survived full range) |

**USDJPY not only survives at this deposit, it's the single most profitable symbol
tested** — but at a materially higher risk cost: **6-7x the equity drawdown percentage**
of EURUSD/GBPUSD (18-20% vs 1-3%). This is a real, load-bearing cross-symbol finding
for §2/§11: USDJPY's default-parameter DCA sequences carry substantially deeper
floating risk than the EUR/GBP pairs, even though the *realized* (balance) drawdown
stays comparatively small (3.6-4.2%) — the same balance-vs-equity divergence pattern
this project has flagged before (`TPSL_EQUITY_BALANCE_ROOT_CAUSE.md`) shows up here
too, at the cross-symbol level rather than the single-strategy level.

**Superseded, not deleted**: the $400-deposit run in §1-3 above remains valuable —
it's now the direct empirical demonstration of *why* the required deposit is
symbol-dependent (a deposit comfortable for EUR/GBP genuinely blows up on USDJPY).
**Going forward, `Deposit=15000` is the reference baseline** for the rest of this
study (optimization grids, portfolio tests), since it's the account's actual real
funded state, not an assumption.

---

## 5. BB Period × Deviation optimization grid — EURUSD (per §4)

**Grid**: `InpBBPeriod` ∈ {20,25,30,35,40,45,50} × `InpBBDeviation` ∈
{1.50,1.75,2.00,2.25,2.50,2.75,3.00} — 49 combinations, chosen as a structured range
around the default (35 / 2.25), 5-unit/0.25-unit increments matching the input's own
precision. `Deposit=15000`, same window/account as §4, `Model=4`, headless
`Optimization=1` (exhaustive — only 49 combos, no need for genetic search). Full raw
results: `roboforex_study/reports/bb_optimization/eurusd_bb_grid.csv`.

**Equity DD % is remarkably stable across the entire grid (1.41%–1.65%)** — BB
parameter choice barely moves the risk profile on EURUSD, a reassuring robustness
signal in its own right (the strategy's risk character isn't parameter-fragile here).

**Profit declines smoothly and monotonically as Deviation increases, in every single
Period row tested** — no isolated spike anywhere in the grid. This is the textbook
"robust region" signature per §6, not a sharp optimum: Deviation 1.50–2.00 consistently
outperforms 2.50–3.00 regardless of which Period it's paired with.

| Rank | Period | Dev | Profit | PF | Recovery | Sharpe | DD% | Trades |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 50 | 1.50 | $874.53 | 3.94 | 4.05 | 1.58 | 1.41% | 233 |
| 2 | 50 | 1.75 | $812.80 | 3.79 | 3.77 | 1.51 | 1.41% | 222 |
| 3 | 30 | 1.50 | $791.57 | 3.65 | 3.08 | 1.46 | 1.65% | 258 |
| 4 | 50 | 2.00 | $774.70 | 3.92 | 3.59 | 1.49 | 1.41% | 200 |
| 5 | 30 | 1.75 | $769.99 | 3.62 | 3.00 | 1.43 | 1.65% | 247 |

Default (35 / 2.25) placed mid-pack at $551.28 — solidly within the same robust
low-deviation neighborhood, not an outlier itself, just not the peak.

**A second, distinct pattern worth flagging** — Profit Factor peaks somewhere else
entirely: `Period=20, Dev=1.75` gives the single highest PF in the grid (4.81, fewer
but higher-quality trades: 234), while the highest-*profit* combos (Period=50) sit at
a noticeably lower PF (~3.8-3.9). This is a genuine PF-vs-total-profit tradeoff, not
noise — smaller Period + low Deviation trades more selectively (higher win quality,
fewer trades, less capital deployed); larger Period + low Deviation trades more often
and compounds more total profit at slightly lower quality per trade. Exactly the kind
of "different objectives, not one best config" distinction §13 asks for: a
robustness-first pick would lean toward `Period≈20-25, Dev≈1.5-1.75`; a
profit-focused pick toward `Period≈45-50, Dev≈1.5-2.0`.

## 6. BB Period × Deviation optimization grid — GBPUSD and USDJPY, cross-symbol comparison

Same grid, same method, same `Deposit=15000` window. Raw results:
`roboforex_study/reports/bb_optimization/{gbpusd,usdjpy}_bb_grid.csv`.

### GBPUSD — a different but still coherent picture

Equity DD% is **not** smooth like EURUSD's — it clusters into two discrete bands (~3.0-3.2%
at Dev≤2.00, dropping to ~1.9-2.2% at Dev≥2.5), a step rather than a gradient, but still
a bounded, sane range overall. **Profit Factor's relationship with Deviation is the
opposite of EURUSD's**: PF *increases* with higher Deviation at higher Periods (Period=45
climbs from PF 2.37 at Dev=1.50 to **3.56 at Dev=3.00**), whereas EURUSD's PF favored *low*
Deviation everywhere. Raw Profit still favors low Deviation (matching EURUSD's direction),
so this is a genuine PF-vs-Profit divergence specific to GBPUSD, not a contradiction of the
profit finding. Top profit region: Period 35-50, Dev 1.50-2.00 — the same general
neighborhood as EURUSD's own top region, which is a reassuring point of cross-symbol
consistency for the *profit-maximizing* zone specifically, even though the DD and PF
character around it differs.

### USDJPY — a genuine sharp discontinuity, not a robust region

This is materially different from both other symbols and needs to be treated with the
caution §6/§17 rule 11 calls for ("treat unusually high PnL or low drawdown as something
to investigate, not automatically good"):

- **Equity DD% jumps as a cliff, not a gradient**: Period=20-25 stays in an 8.25-8.73%
  band; Period=30-50 jumps sharply to **18.2-24.1%** — more than double, with no smooth
  transition in between. This is a regime change in the grid, not a gentle slope.
- **The single highest-profit combinations sit directly in the highest-drawdown region**:
  `Period=30, Dev=1.50` ($4,354.74, the grid's best profit) carries a **24.04% equity
  drawdown** — by far the worst risk in the entire grid. `Period=50, Dev=1.50-2.00`
  ($4,280-4,297) sits at 24.08-24.11% DD, same story. Chasing USDJPY's top-profit row
  means taking on dramatically more risk than any EURUSD/GBPUSD combination tested.
- **A separate corner shows suspiciously high Profit Factor**: `Period=20-25,
  Dev=2.75-3.00` reaches **PF 6.28-7.62** — roughly double the best PF seen anywhere on
  EURUSD or GBPUSD — paired with the *lowest* drawdown band (8.5-8.7%) and the fewest
  trades (136-171 of the grid's ~250-300 typical range). This combination of unusually
  high PF + low trade count + being an isolated corner of the grid (not a broad region)
  is exactly the "investigate, don't celebrate" pattern the study's own rules flag —
  plausibly a small-sample artifact (a handful of large wins skewing the ratio) rather
  than a genuinely robust edge. **Not validated further yet — flagged, not endorsed.**

**Interpretation**: USDJPY's BB-strategy behavior is not simply "the same strategy,
scaled" — it has a qualitatively different risk structure from EUR/GBP, consistent with
§4's earlier finding (USDJPY blew a $400 account, survived and was most profitable at
$15,000, but with far deeper equity drawdown even at default parameters). The
optimization grid confirms this isn't a default-parameter fluke: elevated, discontinuous
drawdown is a structural feature of USDJPY under this strategy across most of the tested
parameter space, not just the default combination.

## 7. Summary so far — robust vs. symbol-specific behavior

| | EURUSD | GBPUSD | USDJPY |
|---|---|---|---|
| Equity DD% pattern across grid | Smooth, tight (1.41-1.65%) | Stepped, two bands (1.9-3.2%) | **Cliff** (8.3-24.1%) |
| Profit vs Deviation | Monotonic, low-Dev wins | Monotonic, low-Dev wins | Monotonic, low-Dev wins (but see DD) |
| PF vs Deviation | Low-Dev wins | **High-Dev wins at high Period** (opposite of EURUSD) | Low-Dev wins generally, except a suspicious high-Dev/low-Period corner |
| Best-profit region's own risk | Low DD (~1.4%) | Moderate DD (~3.1%) | **Worst DD in the whole grid (~24%)** |

The direction "low BB Deviation tends to maximize raw profit" **is** consistent across
all 3 symbols — a genuine cross-symbol robust observation. Everything about *risk*
(drawdown magnitude, its relationship to the profit-maximizing region, and PF's own
relationship to Deviation) is symbol-specific and, for USDJPY, structurally different
in a way that should weigh heavily against simply porting EURUSD's or GBPUSD's
"optimal" parameters onto it without separate scrutiny.

**Not yet done**: full-metric-set deep dives (win rate, consecutive losses, sequence
stats — not in the optimizer's own summary columns) for the specific robust-region
candidates identified here; out-of-sample validation of whichever region holds up
across symbols.

## 8. QQE Oversold/Overbought optimization grid — EURUSD, GBPUSD, USDJPY (complete)

**Grid**: `InpQQEOversold` ∈ {20,25,30,35,40,45} × `InpQQEOverbought` ∈
{55,60,65,70,75,80} — 36 combinations, 5-unit increments per §5's own instruction,
built outward from the default (40/60). Same `Deposit=15000`/window/`Model=4` as the
BB grids. Raw results: `roboforex_study/reports/qqe_optimization/`.

**Status**: EURUSD and GBPUSD completed first; USDJPY's job was killed mid-run by a
background-batch memory-pressure interruption unrelated to this study, then re-run
cleanly (confirmed: correct account/symbol/deposit in the report header, 36/36 combos
present) once the harness had headroom again. All 3 symbols' oversold/overbought grids
are now complete and analyzed below. Per explicit user direction, the SF/WP multiplier
grid (§5's other half — the QQE indicator's own internal smoothing/Wilders-period
constants, not the signal threshold levels) is deprioritized for now, not run for any
symbol.

### Findings (EURUSD + GBPUSD)

Both symbols show the **same clean, monotonic, cross-symbol-consistent direction**:
profit increases steadily as `Oversold` rises toward 50 and `Overbought` falls toward
50 (i.e., a *looser* QQE filter, more signals). This tracks directly with trade count
(4 trades in the tightest/most-selective corner up to 400+ in the loosest) — more
signals compounding into more total profit in an overall-profitable strategy, not a
free lunch.

| | EURUSD | GBPUSD |
|---|---|---|
| Best profit combo | OS=45, OB=55: **$1,623.17**, PF 4.20 | OS=45, OB=55: **$1,662.60**, PF 2.98 |
| Best combo's DD% | 1.80% | 2.82% |
| Best combo's trades | 422 | 440 |
| Default (40/60) profit | $1,195.98 | $1,329.52 |
| Equity DD% range across grid | 0.33%–1.90% | 0.06%–2.94% |

**Important limitation, not a result to hide**: the best combination on *both* symbols
sits at `Oversold=45, Overbought=55` — the **edge of the tested range**, on the side
closest to 50. This means the grid as tested cannot rule out an even better (or
differently-shaped) result just outside it — §6's own rule against "arbitrarily
restricting the range" applies to this finding itself. The range was built symmetrically
outward from the default per §5's instruction, but the result suggests it should be
widened further toward 50 before treating 45/55 as a genuine optimum rather than a
boundary artifact.

**A second, distinct finding needing caution — same pattern as USDJPY's BB grid
corner**: the sparsest-trade corners show wildly inflated Profit Factor that should
NOT be read as edge quality. EURUSD's `Oversold=20-25, Overbought=80` shows PF
7.01–8.01 on just 4–10 trades; GBPUSD's `Oversold=20, Overbought=70` shows PF 5.90 on
49 trades, and `Oversold=20, Overbought=80` degenerates to a single trade (PF
computed as 0.00, meaningless at n=1). **Flagged as small-sample artifacts, not
validated edges** — consistent with this study's own rule to investigate rather than
celebrate unusual results.

### USDJPY — same directional pattern, structurally different risk (consistent with §6)

| | EURUSD | GBPUSD | USDJPY |
|---|---|---|---|
| Best profit combo | OS=45, OB=55: **$1,623.17**, PF 4.20 | OS=45, OB=55: **$1,662.60**, PF 2.98 | OS=45, OB=55: **$5,512.15**, PF 2.70 |
| Best combo's DD% | 1.80% | 2.82% | **19.83%** |
| Best combo's trades | 422 | 440 | 498 |
| Default (40/60) profit | $1,195.98 | $1,329.52 | $5,051.87 |
| Equity DD% range across grid | 0.33%–1.90% | 0.06%–2.94% | **9.01%–21.86%** |

**The direction is identical across all 3 symbols**: `Oversold=45, Overbought=55` — the
same edge-of-tested-range corner closest to 50 — is the single best-profit combination
on USDJPY too, reinforcing (not just repeating) the "looser filter, more signals, more
total profit" pattern already seen on EURUSD/GBPUSD, and the same "this is a range-edge
result, not a confirmed interior optimum" caution applies with 3-symbol weight behind
it now rather than 2.

**The risk magnitude is not identical — USDJPY carries the same structurally deeper
equity drawdown found in the BB grid (§6), independently reconfirmed here on a
different indicator (QQE vs. BB) driving the same underlying DCA position-sizing/
averaging mechanics.** Equity DD% across this entire grid never drops below 9%
anywhere, vs. sub-3% for EURUSD/GBPUSD across their entire grids — this isn't
confined to one corner, it's the whole USDJPY oversold/overbought surface running at
roughly an order of magnitude more floating risk than the other two symbols, for every
parameter combination tested, not just the default.

**Same sparsest-corner PF-inflation artifact recurs on USDJPY too, and more
sharply**: `Oversold=20-25, Overbought=75-80` reaches PF 8.6–11.6 (vs. the grid's
otherwise-typical 2.4–3.5) on the grid's lowest trade counts (26–68 of the ~26–498
range) — the same "investigate, don't celebrate" pattern flagged for EURUSD/GBPUSD's
own corners and the earlier BB-grid USDJPY corner, now a fourth independent
occurrence of the same artifact shape. **Flagged, not validated.**

## 9. Summary — QQE Oversold/Overbought grid, all 3 symbols

The profit-maximizing direction (loosen the filter toward 50/50) is now a **confirmed
cross-symbol pattern across all 3 tested symbols**, holding independently across two
different indicator families (BB and QQE, §7/§8) — the strongest robustness signal
this study has produced so far. USDJPY's structurally elevated equity drawdown is
likewise now confirmed independently across both indicator families, not a BB-specific
or single-grid artifact — this should weigh heavily in any capital-adequacy or
parameter-selection decision for USDJPY specifically (§2/§4's original finding), on
top of the earlier finding that USDJPY needs a fundamentally larger deposit than
EUR/GBP just to survive.

**Not yet done**: the SF/WP multiplier grid (deprioritized per user direction, not
abandoned — revisit if asked); extending the oversold/overbought range closer to 50
given the edge-of-range result confirmed on all 3 symbols now; full-metric deep dives
(win rate, consecutive losses, sequence stats) and out-of-sample validation for
whichever region ultimately gets selected, same open items as the BB grid.
