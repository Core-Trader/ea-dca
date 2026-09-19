# RoboForex Multi-Symbol Study — DCA CENT V1

**Status**: Phase 1 (login/data verification + Strategy A/B individual baselines) complete
for 3 symbols. One critical finding requires a decision before continuing.

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

## 4. Immediate open decision

Before proceeding to the BB/QQE optimization grids (which would otherwise blindly
repeat this blowup dozens of times across every parameter combination on USDJPY),
this needs a decision:

- **(a)** Test USDJPY at a larger starting deposit sized to what its own sequence depth
  actually requires (would need its own capital-sizing pass first, inverting this
  study's own planned order — §11 was meant to come *after* strategy/parameter
  selection, not before).
- **(b)** Keep the $400 deposit but reduce `InpInitialLot`/position sizing specifically
  for USDJPY as part of the optimization grid (turns this into a 3rd, symbol-specific
  sizing variable on top of the BB/QQE parameter grids).
- **(c)** Exclude USDJPY from the parameter-optimization phase for now, keep it as a
  documented capital-adequacy finding, and revisit once EURUSD/GBPUSD's own robust
  regions are established (since USDJPY's optimum parameters can't be meaningfully
  explored while every run blows the account before generating a useful sample).
- **(d)** Something else.
