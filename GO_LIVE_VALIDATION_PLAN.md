# DCA_EA — Go-Live Validation Plan

**Status**: Phase 1 (environment & EA assessment) and Phase 2 (baseline) complete.
Phase 1 answers confirmed by the user (2026-09-17): the live cent account will be a
**different** broker/account than `default.set`'s `Login=540291482` — this terminal's
current account/data is fine for all testing up to the cent-account-specific phase — and
the cent symbols will use a **`c` suffix** (`EURUSDc`, `GBPUSDc`). Phases 3-11 not yet
started.

This document is the audit trail for the go-live process: every phase, test run,
parameter decision and conclusion gets recorded here as it happens. Nothing in this
document should be read as "validated" unless a specific test result is cited.

---

## Phase 1 — Environment & EA Assessment

### 1.1 Testing environment capability

**Confirmed automatable from this session, headless, no user action required:**
- Compilation via `MetaEditor64.exe /portable /compile:"..."` — confirmed working
  throughout this project (most recent clean compile: 0 errors, 0 warnings).
- Single backtests via `terminal64.exe /portable /config:"<ini>"` — confirmed working,
  `Model=4` ("every tick based on real ticks"), with the exact gotchas and working
  `.ini` template already documented in `CLAUDE.md`. **Always run in the foreground**
  (no `run_in_background`), and only after the user explicitly authorizes that specific
  run, per CLAUDE.md.

**Not automatable from this session — requires the user to run manually in the MT5 GUI:**
- **Optimization runs** (`Optimization=1..3` in the `.ini`). Headless optimization is
  technically possible via the same `/config:` mechanism, but a genetic/full
  optimization over any non-trivial parameter space takes far longer than this tool's
  practical turnaround (each call has a hard wall-clock ceiling), and the result lives
  in an `.xml`/cache format that's awkward to parse back out headlessly. **Recommendation:
  I will specify exact parameter ranges/steps/criteria; you run the optimization in the
  MT5 GUI (Strategy Tester → Optimization tab) and share the resulting report (`.xml` or
  exported `.htm`/`.xlsx`) back to me for analysis.** I can inspect and reason about
  optimization output once you provide it, the same way prior discrepancy
  investigations in this project consumed exported `.xlsx`/`.htm` reports.
- **Walk-forward analysis** — MT5's built-in walk-forward optimizer is GUI-only in this
  MT5 build; same handoff as above.
- **Monte Carlo testing** — MT5 has no built-in Monte Carlo tester. This needs either a
  third-party tool/script (e.g. resampling the trade list from a completed backtest) or
  a custom script I write against an exported deal list. I can do the latter — build a
  Python/analysis script that resamples trade sequences from a real backtest's deal
  export and computes a drawdown/ruin distribution — once we have a validated baseline
  deal list to resample from.
- **Anything requiring the actual cent-account broker connection** (real symbol
  specification, real spread/swap/commission, actual margin behavior) — I have no access
  to your broker account. I can tell you exactly what to check and how; you'll need to
  either run a backtest against the cent account's own symbol (if your broker exposes
  historical data for it in the Strategy Tester) or report back live-observed values
  (`SymbolInfoDouble`/`AccountInfoDouble` output, e.g. via a tiny diagnostic script or
  the Market Watch → symbol specification dialog).

**Bottom line**: backtesting and compilation, I can run directly, with your explicit
go-ahead each time. Optimization, walk-forward, Monte Carlo, and anything touching the
live/cent broker connection are a shared workflow — I design the protocol and analyze
results, you execute the run itself.

### 1.2 Project structure & dependencies

```
src/experts/DCA_EA.mq5        — the EA (only file we're taking live)
src/indicators/QMP_Filter.mq5 — runtime dependency (iCustom "QMP Filter")
src/indicators/QQE_Adv.mq5    — runtime dependency (iCustom "QQE Adv")
src/indicators/BB.mq5         — NOT a runtime dependency of DCA_EA.mq5 (it uses the
                                 native iBands(), not this file) — legacy/reference only
src/indicators/MACD_Platinum.mq5 — NOT a runtime dependency — legacy/reference only
```

- Single `#include <Trade\Trade.mqh>` — standard MT5 library, no custom `.mqh` files.
- `QQE_Adv.mq5` and `BB.mq5` both `#include <MovingAverages.mqh>` (standard library).
  `QMP_Filter.mq5` is self-contained.
- All other indicator work (native Bollinger Bands, ATR, MA, HTF Bollinger Bands) uses
  built-in `iBands()`/`iATR()`/`iMA()` — no extra files required.
- **Dependency footprint for live deployment**: `DCA_EA.mq5` + `QMP_Filter.mq5` +
  `QQE_Adv.mq5`, compiled, with the compiled indicators present in the live terminal's
  `MQL5\Indicators\` — confirmed already true in this environment (symlinked per
  `CLAUDE.md`), needs to be replicated on the VPS/live terminal you'll actually trade on.
- Other project files (`src/experts/DCA_EA_V1/V2/V3.mq5`, `Diag_RecoveryCheck.ex5`,
  `DCA_EA_Forensic.mq5`) are development/diagnostic artifacts, not part of the live
  deployment footprint. `CORE_DCA_EA_v1` (sibling project folder) is a separate,
  dormant, from-scratch reimplementation — out of scope for this go-live process unless
  you say otherwise.

### 1.3 Cent-account code audit

No code in `DCA_EA.mq5` reads `AccountInfoString(ACCOUNT_CURRENCY)` or contains any
cent-account detection/adaptation logic. **There is no EA-level safety net for
currency-unit mismatches — correctness depends entirely on the `.set` file being
calibrated for the account's actual currency denomination.** This is the single most
important finding of this phase.

Every monetary/risk-relevant input, categorized:

| Input | Category | Cent-account rescale needed? | Why |
|---|---|---|---|
| `InpInitialLot`, `InpLotPerStep`, `InpMaxInitialLot` | C (position sizing) | No | Lot units are absolute — 0.01 lot means the same contract exposure regardless of account currency. |
| `InpLotPercent` (LOT_PERCENT_BALANCE/EQUITY) | C | No | Percent of `ACCOUNT_BALANCE`/`ACCOUNT_EQUITY`, which MT5 already reports in the account's own currency — self-scaling. |
| `InpStepAmount` (LOT_STEP_BALANCE/EQUITY, default 1000.0) | **B (currency)** | **Yes** | Compared directly against `ACCOUNT_BALANCE`/`ACCOUNT_EQUITY` (`DCA_EA.mq5:953`). On a cent account, "1000" = 1000 cents = $10, not $1000 — the lot-step-up would trigger ~100x more often than intended relative to real dollar equivalent. Not active under default `.set` (`InpLotSizeMode=LOT_FIXED`), but must be rescaled ×100 if that mode is ever used on the cent account. |
| `InpProfitTargetCurrency` (Fixed Target, TARGET_CURRENCY, default 50.0) | **B** | **Yes** | Compared against `GetSequenceProfitMoney()`, which is real account-currency P&L (`DCA_EA.mq5:2518`). Not active under default `.set` (`InpExitStrategy=EXIT_BB_CENTRE_BAND`, `InpFixedTargetType=TARGET_PIPS`), but must be rescaled ×100 if Fixed Target / currency-mode is ever used. |
| `InpTrailingStartDollars` (default 50.0, Pure Trailing Stop) | **B** | **Yes** | Same pattern (`DCA_EA.mq5:2581`). Not active under default `.set` (`InpExitStrategy=EXIT_BB_CENTRE_BAND`), matters if Pure Trailing Stop is ever selected. |
| `InpStopAfterProfitPerSession` (default 0.0 = off) | **B** | **Yes, if enabled** | Compared against `g_sessionRealizedProfit`, real account-currency (`DCA_EA.mq5:1473`). Off by default — fine as-is, but must be rescaled ×100 the moment it's turned on. |
| `InpEquityProtectionAmount` (default 500.0, only used if `InpEquityProtectionMode=EQUITY_PROTECT_AMOUNT`) | **B** | **Yes, if that mode is selected** | Compared against `GetTotalFloatingProfit()`, real account-currency (`DCA_EA.mq5:2678`). Default mode is `EQUITY_PROTECT_PERCENT` (0.6% of balance) — **already self-scaling and cent-account-safe as shipped**, which is the right default for this deployment; don't switch to Amount mode without rescaling. |
| `InpBreakevenBufferPips`, `InpDynamicStopDistancePips`, `InpProfitTargetPips`, `InpTrailingStartPips`, `InpTrailingStepPips`, `InpMinDistancePips`, `InpRiskReductionBufferPips` | A/C (strategy logic, price domain) | No | Pip-denominated, currency-agnostic — a 10-pip move is a 10-pip move regardless of account currency. |
| `InpMaxSpread` (points) | **D (broker/symbol spec)** | Not a currency issue, but **must be re-verified empirically** | Points are a symbol price-precision property, not account currency — but cent-account brokers frequently run the position on a differently-suffixed symbol (`EURUSDc`, etc.) with its own spread/point characteristics that can differ from the standard-account symbol this EA has been tested against all session. Do not assume `InpMaxSpread=40` is still the right calibration on the actual cent-account symbol. |
| `InpMaxTradesPerSequence`, `InpMaxSequencesPerDirection` | A (strategy logic) | No | Trade counts, not currency. |
| `InpEquityProtectionPercent`, all other `%`-suffixed inputs | C | No | Self-scaling by construction. |
| Margin check (`MarginOk()`, `DCA_EA.mq5:1626-1647`) | D | No code issue | Uses `OrderCalcMargin()` + `ACCOUNT_MARGIN_FREE`, both broker-computed and already in account currency — correct by construction regardless of denomination. The real open question is **D-category**: what the cent account's actual leverage/margin requirement is, which I can't know without your broker's real cent-account symbol specification. |

**Summary, in the format requested:**
- **A. Strategy logic** — no cent-account-specific issues; entry/exit rules operate on price/pip distances only.
- **B. Account-denomination effects** — real and non-trivial: 5 inputs (`InpStepAmount`, `InpProfitTargetCurrency`, `InpTrailingStartDollars`, `InpStopAfterProfitPerSession`, `InpEquityProtectionAmount`) are fixed-currency-unit values that silently mean "1/100th of the intended real-dollar amount" if left at their dollar-account defaults on a cent account. **All five are either off or not selected under the current `default.set`, so as shipped, `default.set` is not currently exposed to this bug** — but the moment any of those four modes/features gets turned on for the cent-account `.set`, it must be rescaled ×100 or it will silently do the wrong thing (in the `InpStepAmount` case, dangerously — faster-than-intended lot growth).
- **C. Position-sizing/risk effects** — self-scaling correctly by design (lots and percentages), no action needed.
- **D. Broker/symbol-specification effects** — the real unknown. `InpMaxSpread` calibration, actual `SYMBOL_VOLUME_MIN/MAX/STEP`, actual contract size, actual leverage, and actual swap/commission on the specific cent-account symbol are all things I cannot verify without either (a) the broker's published symbol specification for the cent account, or (b) you running/reporting from the actual cent-account terminal. This is the top blocker for Phase 5 (cent-account validation) and needs your input before that phase can start.

### 1.4 Open questions before Phase 2 can start

1. **Which broker/account will the live cent account actually be on**, and is its
   historical data available in this MT5 terminal's Strategy Tester (so a backtest can
   run against the *actual* cent-account symbol), or only in a separate terminal
   install? The `default.set`'s `Login=540291482` — is that the same broker/account
   type as the intended cent account, or a different (standard) demo?
2. Do you know the cent account's exact **symbol name** (e.g. `EURUSD` vs `EURUSDc` vs
   something else), and can you pull its symbol specification (Market Watch → right
   click → Specification) so I can compare contract size / volume min-max-step / margin
   currency against what the backtests so far have assumed?
3. For Phase 2 (baseline backtest establishing `EA_DCA_CENT_V1.mq5`): do you want me to
   **run it now** (I'll confirm the exact `.ini`/`.set` before launching, per the
   standing rule), or would you rather run it yourself and share the report?

Everything else in this plan (Phases 3-11, deliverables A-K) will be filled in here as
each phase executes — this file will grow into the complete audit trail rather than
being rewritten from scratch.

---

## Phase 2 — Baseline (2026-09-17)

### 2.1 `EA_DCA_CENT_V1.mq5` created

`src/experts/EA_DCA_CENT_V1.mq5` — a frozen snapshot of `DCA_EA.mq5` as of commit
`dccf97b` (post Finding-2 touch-mode fix, post `InpAlwaysCloseOnOppositeBand` notice).
Diffed byte-for-byte identical from the `#include <Trade\Trade.mqh>` line onward — only
the header comment block differs (documents it as the cent-account go-live baseline,
with an explicit "don't hand-edit, re-baseline from `DCA_EA.mq5` instead" rule). Compiled
clean: 0 errors, 0 warnings.

This is the file that will actually go live on the cent account. `DCA_EA.mq5` keeps
being the active development/reference-comparison file; changes only flow from
`DCA_EA.mq5` into a re-baselined `EA_DCA_CENT_V1.mq5` deliberately, never the other way.

### 2.2 Baseline backtest

Run headlessly (`Model=4`, 100% real ticks confirmed in the report), settings verified
against the report's own Settings section before trusting the result (per CLAUDE.md):

| | |
|---|---|
| Expert | `EA_DCA_CENT_V1` (confirmed in report) |
| Symbol / Period | EURUSD / H4 |
| Range | 2025.01.01 - 2026.01.22 |
| Deposit / Currency / Leverage | 100,000 / USD / 1:30 (current dev account — **not** the cent account; see note below) |
| `.set` | `EA_DCA_CENT_V1_baseline.set` = `default.set`'s values, byte-identical (`InpBBAppliedPrice=3`/PRICE_HIGH, `InpAlwaysCloseOnOppositeBand=false`, etc. all confirmed present in the report) |
| Artifacts | `diagnostics/backtests/cent_v1_baseline/` (report `.htm`, 4 chart `.png`s, the `.set` used) |

**Note on scope**: per your answer to open question 1, this baseline intentionally still
runs on the current (non-cent) account/symbol — establishing a reproducible, correctly-
configured baseline is the goal of this phase, not cent-account economics yet (that's
Phase 5, blocked on getting real `EURUSDc`/`GBPUSDc` symbol specifications).

### 2.3 Baseline results

| Metric | Value |
|---|---|
| Total Net Profit | **$225.70** |
| Gross Profit / Gross Loss | $275.62 / -$49.92 |
| Profit Factor | 5.52 |
| Expected Payoff | $3.89/trade |
| Recovery Factor | 2.32 |
| Sharpe Ratio | 2.79 |
| Balance Drawdown (abs / max) | $0.03 / $7.87 (0.01%) |
| Equity Drawdown (abs / max) | $11.52 / $97.33 (0.10%) |
| Total Trades / Total Deals | 58 / 116 |
| Win rate | 74.14% (43 profit / 15 loss trades) |
| Long / Short split | 37 long (72.97% won) / 21 short (76.19% won) |
| Largest win / loss | $41.90 / -$7.84 |
| Average win / loss | $6.41 / -$3.18 |
| Max consecutive wins | 8 trades ($36.72) |
| Max consecutive losses | 2 trades (-$6.24); single largest losing streak -$7.84 |
| Min / Max / Avg position holding time | 1 sec / 316h05m / 60h38m |
| **Total commission** (derived, summed across all 116 deals) | **-$4.44** |
| **Total swap** (derived, summed across all 116 deals) | **-$20.68** |

**Finding worth flagging**: the sum of the deal log's own per-deal `Profit` column
(pure trading P&L, excluding commission/swap) is **$250.82** — commission (-$4.44) and
swap (-$20.68) together account for the ~$25.12 gap down to the reported $225.70 net.
Swap alone is ~8% of gross profit over this period, driven by this strategy's multi-day
average hold time (60h38m) — **this cost was not part of any prior investigation in this
project** (those used a different comparison methodology) and needs to be re-verified
against the actual cent-account's swap rates in Phase 5, since cent accounts sometimes
have different (occasionally zero) swap terms than standard accounts on the same broker.

Trade sequence was inspected directly (not just aggregate stats) via the deal log —
entries/exits, lot progression per sequence (e.g. 0.01 → 0.02 add-on pattern), and
commission/swap per deal all read individually, consistent with the settings shown.

This baseline number ($225.70 net / $250.82 gross-of-costs) is a fresh, independent
measurement for this go-live track — it's close to, but not required to exactly match,
numbers from the earlier `PNL_DISCREPANCY_ROOT_CAUSE_REPORT.md` investigation, since
that used a different reporting/comparison methodology. Both are valid; this one is now
the baseline of record for go-live purposes.

---

## Phase 3 — Backtest Protocol

User instruction for phases 3 onward: proceed autonomously, applying established/
proven methodology rather than stopping to ask at each step. Decisions below follow
standard walk-forward practice (optimize on one block, validate on separate untouched
blocks; never optimize on the full dataset) — deviations from that are called out
explicitly where the available data forces a compromise.

### 3.1 Critical finding: real broker tick data on this account only goes back to ~mid-2024

Probed `EURUSD` `History Quality` (the % of the tested range backed by actual broker
tick data vs. MT5's synthetically-generated filler) across several eras, same account
(`Login=540291482`, FTMO-Server4) used for all testing so far:

| Period tested | History Quality |
|---|---|
| 2010.01.01 - 2010.03.31 | **0% real ticks** |
| 2015.01.01 - 2015.03.31 | **0% real ticks** |
| 2020.01.01 - 2020.03.31 | **0% real ticks** |
| 2023.01.01 - 2023.03.31 | **0% real ticks** |
| 2023.10.01 - 2024.04.01 | 25% real ticks (mixed — transition zone) |
| 2024.09.01 - 2025.02.01 | **100% real ticks** |
| 2025.01.01 - 2026.01.22 (Phase 2 baseline) | **100% real ticks** |

**This means every `.hcs` history file back to 2004 that MT5 downloaded for the wide
probe is misleading — it exists on disk, but the pre-~2024 portion is synthetic filler,
not real market data.** This matters specifically for this EA because it has
already-confirmed touch-mode logic (`InpBBExitOnBreach=true`, live-tick sensitive —
see `PNL_DISCREPANCY_ROOT_CAUSE_REPORT.md` Finding 2) whose behavior depends on the
actual intrabar tick path, not just OHLC bar values. Backtesting that logic against
synthetic filler data would produce a number, but not a meaningful one. **Conclusion:
only ~2024-09 onward is usable for any conclusion this plan relies on.** Multi-decade
regime coverage (2008 crisis, 2011 EU debt crisis, 2015 CHF unpeg, 2020 COVID crash,
etc.) is simply not available with real fidelity on this account/broker demo server —
stated plainly rather than assumed away, per the "do not hide inconclusive results"
principle. If regime coverage against those historical shocks specifically matters to
you, it would require a different data source/broker feed than this environment has;
flagging this now rather than silently settling for synthetic-data theatre.

### 3.2 Second symbol: GBPUSD (needed — the cent account will trade `GBPUSDc` too)

Every test in this project to date, across the entire session, has used EURUSD only.
The cent account's confirmed instruments are `EURUSDc` and `GBPUSDc`. Ran the same
`EA_DCA_CENT_V1_baseline.set` unchanged against `GBPUSD`, 2025.01.01-2026.09.17,
`Model=4`:

| | EURUSD (Phase 2 baseline) | GBPUSD (same params, unmodified) |
|---|---|---|
| History Quality | 100% real ticks | 100% real ticks |
| Total Net Profit | $225.70 (13.5 mo window) | $282.42 (20.5 mo window) |
| Profit Factor | 5.52 | **2.11** |
| Total Trades | 58 | 108 |
| Equity Drawdown Maximal | $97.33 (0.10%) | **$183.09 (0.18%)** |

**Finding**: the EA is not blowing up on GBPUSD, but its risk/reward character is
materially different under EURUSD-derived parameters — roughly half the profit factor
and nearly double the relative drawdown. This is expected (nothing about this EA's
parameters was ever tuned with GBPUSD in mind) but it means **`GBPUSDc` cannot simply
inherit the EURUSD-validated `.set` file at go-live** — it needs its own baseline/
optimization/validation pass through this same protocol before being trusted with real
money, even in cent-account terms. Tracked as a required parallel track, not yet done.

### 3.3 Backtest protocol, as adopted

| Parameter | Value | Rationale |
|---|---|---|
| Symbols | EURUSD (primary track), GBPUSD (secondary track, own optimization required — §3.2) | Matches the two confirmed cent-account instruments |
| Timeframe | H4 | Matches all prior project work and `default.set` |
| Tick/model quality | `Model=4` ("every tick based on real ticks") only, never `Model=1` | Confirmed elsewhere in this project that `Model=1`'s synthetic intrabar path diverges from real/GUI runs for this EA's touch-mode logic (see `CLAUDE.md`) |
| Usable historical window | **2024-09-01 to present** only | Real-tick-quality floor established in §3.1; anything earlier is synthetic filler on this account |
| Spread/commission/slippage | Not separately assumed — real historical spread is embedded in the real-tick simulation; real commission (~$0.03/0.01 lot/side) and swap are broker-modeled and already visible in the Phase 2 deal log; `InpSlippage=3` points is the EA's own execution-slippage allowance, unchanged | Using modeled real costs is more realistic than a hand-picked flat assumption, and is already proven to work (Phase 2) |
| Initial balance / leverage (dev-track testing) | 100,000 / USD / 1:30 | Matches this account; **not** representative of the $150 cent account — that is Phase 5's concern specifically, not this protocol's |
| Magic number | `123456` (unchanged from `default.set`) throughout dev-track testing | Consistency across comparable runs; will need a distinct magic number per live symbol/instance at actual go-live to avoid cross-EA position confusion |
| Trading session restriction | None (`InpUseTimeFilter=false`) | Matches `default.set`; no evidence yet that session-restricting improves anything — not changed without a reason, per the "don't change parameters without documenting why" principle |

### 3.4 In-sample / out-of-sample split

The natural split is **not** an arbitrary 70/30 — it follows from what's already
happened in this project. Everything from `2025.01.01` to `2026.01.22` has effectively
already been "seen": the `Visual_test_2025.xlsx` discrepancy investigation, the
`PNL_DISCREPANCY_ROOT_CAUSE_REPORT.md` PnL-gap investigation, and Phase 2's baseline
all ran on exactly this window, and Finding 2's fix was derived by inspecting specific
trades inside it. Calling that window "out-of-sample" now would be self-deception —
real development decisions were made using knowledge of what happens inside it.

So the split is:

- **In-sample / development window (already used, legitimate for optimization)**:
  `2025.01.01 - 2026.01.22` (~13 months).
- **Out-of-sample validation A ("pre-history", never touched by any decision this
  project made)**: `2024.09.01 - 2024.12.31` (~4 months, the earliest slice with
  confirmed 100% real-tick quality).
- **Out-of-sample validation B ("forward", never touched — didn't exist yet when
  every prior investigation's `ToDate` cutoff was set)**: `2026.01.23 - 2026.09.17`
  (~8 months, the most recent, most realistic "would this actually have worked"
  window).

Total genuinely out-of-sample evidence available: ~12 months, split across two
disjoint windows rather than one contiguous block — arguably better than one block
for catching regime-dependence, since it forces the parameters to work across two
separate stretches of time it was never fitted to. This is a real constraint (a
strategy this data-limited cannot support an aggressive multi-fold walk-forward the
way a 10+-year, fully-real-tick dataset could) and is stated as such rather than
glossed over — flagged for Phase 4's overfitting-risk assessment specifically.

### 3.5 Out-of-sample validation results (unmodified baseline, no optimization applied yet)

Ran `EA_DCA_CENT_V1_baseline.set` — completely unchanged, nothing tuned — against both
untouched windows:

| | In-sample (2025.01.01-2026.01.22, ~12.7 mo) | OOS-A (2024.09-2024.12, ~4.0 mo) | OOS-B (2026.01.23-2026.09.17, ~7.8 mo) |
|---|---|---|---|
| Net Profit | $225.70 | $37.13 | $172.56 |
| **Net Profit / month** | **~$17.80** | ~$9.28 | **~$22.04** |
| Profit Factor | 5.52 | 1.61 | 5.65 |
| Sharpe Ratio | 2.79 | 0.51 | 3.26 |
| Recovery Factor | 2.32 | 0.36 | 2.16 |
| Trades / Deals | 58 / 116 | 19 / 38 | 45 / 90 |
| Equity DD Maximal | $97.33 (0.10%) | $102.91 (0.10%) | $79.71 (0.08%) |

**Reading this honestly**: OOS-A is the weak result — profit factor drops to 1.61 and
Sharpe to 0.51, though still net positive with no drawdown blowout. With only 19 trades
in a 4-month window, this is too small a sample to draw a strong conclusion either way
(a handful of trades going the other way would flip the sign) — it's a data point, not
a verdict. OOS-B is markedly stronger, in fact matching or slightly exceeding in-sample
performance. **Combining both OOS windows and normalizing by time** (since they're
different lengths): $209.69 over ~11.8 months ≈ **$17.73/month**, essentially identical
to in-sample's ~$17.80/month. That closeness, across two disjoint periods the
parameters were never fitted to, is a genuine (if modest, given the small combined
trade count of 64) piece of evidence against gross overfitting — not proof of
robustness, but the opposite of a red flag. No parameter has been changed to produce
this result; it is what the already-developed baseline does on data it has never seen.

---

## Phase 4 — Optimization Methodology

### 4.1 Why this will be a narrow, sensitivity-driven pass, not a broad grid/genetic search

The in-sample window has 58 trades. A multi-parameter grid or genetic optimizer
routinely evaluates thousands of parameter combinations; with that few trades to score
against, it is close to guaranteed to find a combination that overfits the specific
58-trade sequence rather than a genuinely better strategy — the classic failure mode
this whole go-live process is designed to avoid (brief §4: "optimize for robustness,
not maximum historical profit"). **Decision: no broad optimization space.** Instead,
each candidate parameter is swept one at a time, small step count, evaluated against
both profit-factor stability *and* the two out-of-sample windows already established in
§3.5 — never against in-sample net profit alone.

### 4.2 Parameters considered for sensitivity testing, and why

| Parameter | Current (`default.set`) | Proposed test range | Step | Why |
|---|---|---|---|---|
| `InpBreakevenBufferPips` | 10.0 | 5, 10, 15, 20, 25 | 5 | Recovery Mode's real economic lever — directly trades win-rate against average-win-size; worth confirming 10 isn't a knife-edge. |
| `InpMaxSequencesPerDirection` | 3 | 1, 2, 3, 4 | 1 | Caps simultaneous exposure — a risk-sizing lever as much as a performance one; relevant to Phase 9's catastrophic-loss containment on a $150 account, not just PnL. |
| `InpMaxTradesPerSequence` | 0 (unlimited) | 0, 4, 6, 8 | — | Currently uncapped — the single biggest tail-risk lever in a DCA/martingale-style EA (an unbounded losing sequence keeps adding lots). Testing whether a cap costs meaningful profit or is free insurance. |
| `InpBBPeriod` / `InpBBDeviation` | 35 / 2.25 | 30/40 (period), 2.0/2.5 (deviation) | 5 / 0.25 | Core signal parameters — confirming the spec-derived defaults sit in a stable region, not a sharp local peak. |

### 4.3 Parameters deliberately EXCLUDED from optimization

- **`InpMultiplierSystem`** (Safe/Linear/Fibonacci/Aggressive/Martingale/Custom) — this
  is a risk-tolerance *choice*, not a tunable knob. A backtest will almost always show
  a more aggressive multiplier (Aggressive/Martingale) producing a higher historical
  profit factor, right up until the one losing streak it can't recover from — that is
  the DCA-strategy overfitting trap by definition. Selecting this by backtest
  performance would directly contradict the brief's own governing principle. It stays
  at the already-decided `MULT_LINEAR`.
- **`InpInitialLot` and all lot-sizing inputs** — these must be *derived* from the
  account's real risk budget (Phase 5/9), not fitted to historical PnL. Sizing up
  lots always improves backtest net profit; it says nothing about whether the account
  can survive the drawdown that comes with it.
- **`InpExitStrategy`** — already selected (BB Centre Band) after the extensive,
  evidence-based investigation earlier in this project (`PNL_DISCREPANCY_ROOT_CAUSE_REPORT.md`).
  Re-opening this as an "optimizable parameter" would discard that validated work for
  no new evidence.
- **`InpSlippage`** — should reflect real broker execution characteristics observed
  live, not be tuned to make backtests look better.
- **`InpMaxSpread`** — already directly investigated (Finding 1, this project) via a
  real 0/100/400/1000 sensitivity sweep: <$2 PnL impact across the entire range. Not
  worth re-testing; already known to be a non-driver.
- **Magic number, comment, all display/panel/color inputs** — no strategy effect.

### 4.4 Evaluation criteria (robustness over peak profit, per the brief's governing principle)

A parameter value is only preferred over the current default if it improves or holds
profit factor **and** does not increase max relative drawdown **and** keeps a comparable
trade count (a large drop in trade count on the same data usually just means "found a
narrower, luckier subset," not a better strategy) **and** does not regress OOS-A/OOS-B
performance judged against §3.5's own baseline numbers. A value that only wins on raw
in-sample net profit is explicitly rejected by this criteria set — that is precisely the
"change → backtest → compare PnL → repeat" pattern this project has already had to walk
back once this session (`PNL_DISCREPANCY_ROOT_CAUSE_REPORT.md`'s own methodology
section) and is not being repeated here.

Sweep execution and results for §4.2's four candidates follow below as they're run.
All four are now complete (§4.5-§4.9).

### 4.5 `InpBreakevenBufferPips` sweep — result: REJECT any increase, keep default (10)

In-sample (2025.01.01-2026.01.22):

| Buffer | Net Profit | Profit Factor | Recovery Factor | Sharpe | Trades |
|---|---|---|---|---|---|
| 5 | $207.73 | 4.99 | 2.13 | 2.61 | 58 |
| **10 (current)** | **$225.70** | **5.52** | **2.32** | **2.79** | **58** |
| 15 | $225.78 | 5.52 | — | — | 58 |
| 20 | $276.57 | 7.38 | 2.84 | 2.93 | 60 |
| 25 | $297.15 | 8.47 | 3.05 | 3.13 | 60 |

Read naively, this looks like "higher is better, monotonically" — exactly the seductive
pattern §4.1 warned about. Per the evaluation criteria in §4.4, the top in-sample
candidate (25) was tested against **both** out-of-sample windows before drawing any
conclusion:

| | OOS-A baseline (buf=10) | OOS-A buf=25 | OOS-B baseline (buf=10) | OOS-B buf=25 |
|---|---|---|---|---|
| Net Profit | $37.13 | $115.78 | $172.56 | $419.60 |
| Profit Factor | 1.61 | 1.86 | **5.65** | **3.81** |
| Recovery Factor | 0.36 | **0.31** | **2.16** | **0.69** |
| Sharpe Ratio | 0.51 | 0.52 | **3.26** | **1.10** |
| Equity DD Maximal | $102.91 (0.10%) | **$378.45 (0.38%)** | $79.71 (0.08%) | **$606.11 (0.61%)** |

**This is a clean, concrete demonstration of exactly the overfitting mechanism this
methodology exists to catch.** A higher breakeven buffer makes the EA hold
recovering/losing sequences open longer before it will close them — in-sample, that
shows up as purely "bigger wins, better everything," because it's measuring a period
that already happened to resolve favorably eventually. Out-of-sample, the same behavior
shows its real cost: raw net profit went up on both OOS windows (more time in the market
before closing = bigger swings both ways, and these two windows both happened to end up
positive), but every risk-adjusted metric got worse — Sharpe collapsed from 3.26 to 1.10
on OOS-B, Recovery Factor from 2.16 to 0.69, and equity drawdown roughly **8x worse**
(0.08% to 0.61%) on the very window where it also made the most extra money. That
combination — more profit, much worse risk-adjusted quality and much deeper drawdown —
is precisely what "optimizing for robustness, not maximum historical profit" is meant to
prevent, and precisely why §4.4's criteria require checking OOS before accepting any
in-sample improvement.

**Decision: `InpBreakevenBufferPips` stays at the current default, 10.** The 10-15
region is a genuine flat, stable plateau (225.70 vs 225.78, indistinguishable) — a
reassuring finding in its own right, since it means the current default isn't sitting on
a knife-edge. 20 and 25 are rejected despite their attractive in-sample numbers, with
the OOS evidence to show exactly why.

### 4.6 `InpMaxSequencesPerDirection` sweep — result: free risk reduction available, decision deferred to Phase 6/9

In-sample:

| Value | Net Profit | Profit Factor | Trades |
|---|---|---|---|
| 1 | $214.93 | 5.57 | 57 |
| 2 | $225.70 | 5.52 | 58 |
| **3 (current)** | **$225.70** | **5.52** | **58** |
| 4 | $225.70 | 5.52 | 58 |

2, 3, and 4 are **byte-identical** — the current in-sample window never actually needed
more than 2 concurrent sequences per direction; the cap of 3 (or 4) never bound. Value 1
(never more than one sequence open at a time) costs only ~$10.77 (4.8%) of net profit.
**This means capping at 2 is free** in this dataset, and capping at 1 is nearly free —
both directly reduce simultaneous exposure, which matters for a DCA-style EA on a $150
account (see Phase 9's "runaway position accumulation" failure mode). Not changed in
`default.set` here — this is flagged as a strong candidate for the live/cent `.set`
specifically, where capital preservation matters more than the last few dollars of
in-sample profit, and decided together with Phase 9's hard-limit framework rather than
in isolation.

### 4.7 `InpMaxTradesPerSequence` sweep — result: free risk reduction available, same deferral

In-sample:

| Value | Net Profit | Profit Factor | Trades |
|---|---|---|---|
| **0 = unlimited (current)** | **$225.70** | **5.52** | **58** |
| 4 | $225.70 | 5.52 | 58 |
| 6 | $225.70 | 5.52 | 58 |
| 8 | $225.70 | 5.52 | 58 |

All four values — including capping every sequence's DCA ladder at just 4 trades —
produce **byte-identical** results. No single sequence in this ~13-month in-sample
window ever grew beyond 4 trades. §4.2 flagged this input as "the single biggest tail-
risk lever in a DCA/martingale-style EA (an unbounded losing sequence keeps adding
lots)" — this result shows a cap of 4 (or even a bit higher, for margin) would have cost
**zero** historical profit while providing a hard ceiling against runaway lot
accumulation in a scenario this ~2-year dataset hasn't produced. Same deferral as §4.6:
flagged as a strong, evidence-backed candidate for the live `.set`'s hard limits, decided
together in Phase 9 rather than changed here for its own sake.

### 4.8 BB Period sweep — result: REJECT both directions, current default (35) confirmed best risk-adjusted

In-sample:

| Period | Net Profit | Profit Factor | Sharpe | Equity DD Max | Trades |
|---|---|---|---|---|---|
| 30 | $283.17 | 3.28 | 1.31 | **0.25%** | 69 |
| **35 (current)** | $225.70 | **5.52** | **2.79** | **0.10%** | 58 |
| 40 | $261.61 | 5.48 | 1.95 | 0.20% | 61 |

Both neighbors show *higher raw net profit* than the current default — and *worse*
profit factor, Sharpe, and roughly 2-2.5x worse drawdown. This is the same pattern as
§4.5 (raw profit up, risk-adjusted quality down) but even clearer, since it shows up on
both sides of the current value rather than in one direction. No OOS check needed to
reject these — they already fail the §4.4 criteria on in-sample risk metrics alone.
**Decision: keep `InpBBPeriod=35`.** Genuinely reassuring: the current default isn't
just "not the worst option," it's the best risk-adjusted one among its immediate
neighbors, on data the value wasn't fitted to using this exact test.

### 4.9 BB Deviation sweep — result: REJECT increase, current default (2.25) confirmed

In-sample:

| Deviation | Net Profit | Profit Factor | Sharpe | Equity DD Max | Trades |
|---|---|---|---|---|---|
| 2.0 | $245.35 | 5.71 | 2.81 | 0.10% | 66 |
| **2.25 (current)** | $225.70 | **5.52** | 2.79 | 0.10% | 58 |
| 2.5 | $217.94 | **7.02** | **3.04** | 0.10% | 49 |

Unlike §4.5/§4.8, this one didn't show an obvious in-sample red flag — drawdown stayed
flat across all three values, and 2.5 looked like a genuine improvement (better PF,
better Sharpe, fewer but presumably higher-quality trades). Per §4.4, checked the top
candidate (2.5) against both OOS windows before accepting it:

| | OOS-A baseline (2.25) | OOS-A dev=2.5 | OOS-B baseline (2.25) | OOS-B dev=2.5 |
|---|---|---|---|---|
| Profit Factor | 1.61 | 1.59 | 5.65 | **5.29** |
| Sharpe Ratio | 0.51 | 0.37 | 3.26 | **3.08** |
| Recovery Factor | 0.36 | 0.34 | 2.16 | **1.99** |
| Trades | 19 | 16 | 45 | 41 |

No drawdown blowup this time (unlike §4.5) — but the apparent in-sample edge simply
**does not generalize**: every metric on both OOS windows is flat-to-slightly-worse than
what the current default already achieves on that same data, including profit factor
falling below the current default's own OOS-B result (5.29 vs 5.65). This is a quieter,
less dramatic version of the same lesson as §4.5: an in-sample-only improvement that
evaporates out of sample. **Decision: keep `InpBBDeviation=2.25`.**

### 4.10 Phase 4 summary

No parameter change is being made to `default.set`/`EA_DCA_CENT_V1_baseline.set` as a
result of this optimization pass. Three of four sweeps (`InpBreakevenBufferPips`,
`InpBBPeriod`, `InpBBDeviation`) directly confirmed the existing spec-derived defaults
are already at or near the best risk-adjusted point among their tested neighbors — a
meaningful result in itself, arrived at by trying to beat the defaults and failing to,
not by assumption. The other two (`InpMaxSequencesPerDirection`,
`InpMaxTradesPerSequence`) surfaced genuine, zero-cost risk-reduction opportunities,
deliberately not applied here in isolation — they're carried forward to Phase 6
(production `.set` construction) and Phase 9 (catastrophic-loss hard limits), where they
belong together with the account's real risk budget rather than being bolted on
mid-optimization for their own sake.

### 4.11 Walk-forward analysis — assessed as not informative given data volume, not run

MT5's built-in walk-forward optimizer is GUI-only (Phase 1 finding). More importantly,
running it wouldn't add real signal here: a proper walk-forward needs enough data for
several rolling optimize/test folds, each with enough trades to be statistically
meaningful. This project has ~24 months of real-tick data and 58 in-sample trades total;
slicing that further into multiple rolling folds would produce folds with a handful of
trades each — too thin to distinguish a real pattern from noise. The 2-window
in-sample/out-of-sample split already done in §3.4-3.5 **is** effectively a single-fold
walk-forward, and is the most granular one this dataset can honestly support. Stated
plainly rather than running a formal walk-forward for the sake of ticking the box and
presenting noisy, uninterpretable fold-by-fold numbers as if they meant something.

### 4.12 Spread/slippage stress test — already done earlier this project, reconfirmed still valid

A controlled `InpMaxSpread` sweep (0/100/400/1000 points) was already run earlier in
this project (`PNL_DISCREPANCY_ROOT_CAUSE_REPORT.md`, Finding 1): net profit varied by
less than $2 across the entire range, despite unlocking materially more trades at the
loose end. That mechanism (the spread gate on new-sequence entries) hasn't been touched
by any change made since — including the Finding 2 exit-timing fix and this project's
own `EA_DCA_CENT_V1.mq5` baselining — so the conclusion still holds: **this EA's PnL is
not meaningfully spread-sensitive** within any realistic range. Not re-run here to avoid
duplicating already-solid evidence. A true execution-slippage stress test (beyond
spread) isn't directly possible in MT5's Strategy Tester — it has no independent
"apply N points of adverse slippage to every fill" lever; `InpSlippage=3` is the EA's own
maximum-deviation tolerance at send time, not a backtest-simulated cost. Real slippage
characteristics will only be knowable from live/forward-test execution data (Phase 7).

### 4.13 Monte Carlo testing (trade-resampling bootstrap)

Built directly from real backtest deal logs (no synthetic data), per the approach
flagged as feasible in Phase 1. Extracted each closed position's net realized cash
impact (profit + that deal's commission + swap, read directly from consecutive Balance
column differences on `out`-type deals) — 58 from the in-sample baseline, 19 from OOS-A,
45 from OOS-B. Resampled these **with replacement** to build randomized equity paths and
see how much the specific historical trade *ordering* matters, independent of the
strategy's average edge.

**Run 1 — in-sample trades only (58-trade pool, 20,000 simulated 58-trade paths)**:
worst outcome across all 20,000 reshuffles still ended net positive (worst final balance
$100,002.54 vs. $100,000 start); median max drawdown $11.03, 99th percentile $26.13,
absolute worst-case-of-20,000 $51.02. Taken alone, this looks almost too good — because
it is: resampling only the strongest of the three known windows can't produce anything
worse than what that window's own trades allow.

**Run 2 — pooled across all three windows (122-trade pool: in-sample + OOS-A + OOS-B,
20,000 simulated 58-trade paths)** — the more representative, appropriately more
conservative version, since it lets a simulated path draw disproportionately from
OOS-A's weaker trades:

| | Value |
|---|---|
| Median max drawdown | $23.64 |
| 95th percentile max drawdown | $42.94 |
| 99th percentile max drawdown | $56.65 |
| Worst of 20,000 simulated paths | $98.67 |
| Probability of a path ending net negative | **0.02%** (4 of 20,000) |

**Explicit limitations of this method** (per the "distinguish assumptions from empirical
observations" principle): this bootstrap can only reorder trade outcomes that actually
occurred in the ~24 months of real data available — it cannot invent a worse single loss
than the worst one actually observed, and it says nothing about a genuinely new regime
or a structural change in the strategy's win rate. It measures *sequencing/ordering
risk* given the empirically observed trade distribution, not *tail risk beyond what's
been seen*. With only 122 pooled trades, the 99th-percentile estimate itself is a noisy
estimate, not a precise figure. All figures above are on the $100,000 test-account scale
and are **not yet rescaled to the $150 cent account** — that rescaling depends on
Phase 5/6 decisions (lot sizing, risk caps) not yet finalized, and is explicitly a Phase
5/6 task, not done prematurely here.

---

## Phase 9 — Catastrophic-Loss Prevention (defense-in-depth)

Moved ahead of Phase 5 (still blocked on the real cent-account symbol specification)
since this is pure code audit + risk-framework design, not something that needs a
broker connection. Findings feed directly into Phase 6 (production `.set`) and Phase 8
(emergency thresholds).

### 9.1 What the EA already protects against (verified in code, not assumed)

| Protection | Where | What it does |
|---|---|---|
| Magic-number collision lock | `CheckMagicNumberCollision()`/`MagicLockName()`, `DCA_EA.mq5:507-552` | A terminal Global Variable keyed by Symbol+Magic hard-blocks a second live chart from running the same Symbol+Magic combination — prevents two EA instances fighting over the same positions. |
| Pre-trade margin check | `MarginOk()`, `:1626-1647` | Computes real required margin via `OrderCalcMargin()` and rejects (logs, doesn't crash) if it exceeds `ACCOUNT_MARGIN_FREE` — checked on **every** entry, new-sequence and add-on alike (`:1865`, `:1901`). |
| Spread gate | `SpreadOk()`, `:1136`, checked at `:1849` (add-ons) and `:1890` (new sequences) | Blocks entries above `InpMaxSpread` — covers both entry types, not just new sequences. |
| Indicator-handle validity | `OnInit()`, every `INVALID_HANDLE` check + every `CopyBuffer(...) > 0` guard throughout | A failed/missing indicator handle or a `CopyBuffer()` short-read causes that check to fail closed (skip the bar/gate) rather than act on stale or zero-filled data. |
| State persistence across restarts | `SaveState()`/`LoadState()`, `:1479-1572`, `:2739-2760` | Full sequence/latch/session state written to a per-Symbol+Magic file, reloaded on `OnInit()`. Structural events (new trade, sequence close) bypass the routine per-tick save throttle specifically so a crash between saves loses as little state as possible. |
| Stale-ticket guard | `:1765-1781` | Re-verifies a remembered position ticket's symbol+magic before trusting it, rather than assuming ticket numbers are never reused. |
| Algo-trading permission checks | `OnInit()`, `:468-479` | Hard-fails if `TERMINAL_TRADE_ALLOWED`/`ACCOUNT_TRADE_ALLOWED`/`ACCOUNT_TRADE_EXPERT` aren't all set. |
| Exit-strategy/Indicator-mode compatibility gate | `ValidateExitStrategyCompatibility()`, `:564-610` (Phase 1) | Hard-fails invalid combinations rather than silently running broken logic. |
| Malformed custom-multiplier-string guard | `ValidateCustomMultiplierString()` (Phase 1) | Hard-fails rather than silently parsing to 0.0 and zero-sizing a trade. |
| Equity Protection (Close All) | `InpUseEquityProtection` + `EQUITY_PROTECT_PERCENT`/`AMOUNT`, `:2660-2680` | **CORRECTED (previously mischaracterized in this row — see the strike-through note in §9.2)**: this is a **profit-lock**, not a loss-stop. Per its own header comment (`:2655-2669`) it closes everything once *combined floating profit* reaches the threshold, to lock in gains before they reverse — offline simulation cited in that comment specifically tuned it against *winning* sequences. It does not fire on losses at all. |

### 9.2 What's missing or off by default — the real gaps

- **CORRECTION (found and fixed during the Phase 5 cent-account discussion, before any
  live decision was made on the strength of the original wrong reading)**: this section
  originally described `InpUseEquityProtection` as a loss-based circuit breaker and
  recommended turning it on as one. That was wrong — re-reading its own header comment
  (`:2655-2669`) shows it closes everything on *combined floating profit* reaching the
  threshold (a portfolio-wide profit lock), not on loss. **This means the honest finding
  is more serious than originally stated: there is currently no loss-based circuit
  breaker anywhere in this EA at all** — not off-by-default, genuinely absent. The only
  things that can stop an adverse sequence today are (1) its own exit strategy
  eventually triggering (no cap on how far price can move first), (2) the broker's
  margin-call/stop-out (RoboForex: 30% margin level, Phase 5.1 — a very late, blunt
  backstop, not risk management), and (3) manual intervention per Phase 8. A genuine
  max-floating-loss circuit breaker does not exist in the code today and would need to
  be added — tracked as the priority candidate for `EA_DCA_CENT_V1.mq5` specifically
  (see the cent-account capital-adequacy discussion this plan's chat history led to).
- **`InpMaxTradesPerSequence=0` (unlimited) in the current `default.set`.** Already
  flagged in §4.7: in ~24 months of real data no sequence ever needed more than 4
  trades, and capping costs nothing historically. Combined with the point below, this is
  the second concrete, free-to-apply hard limit for Phase 6.
- **No fixed stop-loss anywhere, by explicit design** (`DCA_EA.mq5`'s own header:
  *"No fixed stop-loss: risk is controlled entirely by lot sizing, sequence caps, and
  the chosen exit strategy"*). This is a deliberate strategy characteristic, not a bug —
  but it means, combined with the two points above, that **before Phase 6's hard caps
  are actually applied, there is currently no hard per-sequence loss ceiling at all**
  other than the broker's own margin call/stop-out — which happens far too late to be
  called risk management. This is the most important single reason §4.6/§4.7's "free"
  caps need to actually be applied in Phase 6, not just noted as available.
- **No explicit reconnection-state reconciliation.** State persistence (§9.1) covers EA
  restart/terminal restart, but there's no code that, specifically on regaining
  connection after a network drop, re-verifies the broker's actual open positions
  against the EA's internal `g_buySequences`/`g_sellSequences` arrays before resuming
  decisions. MT5 generally handles this gracefully on its own (no `OnTick()` calls fire
  while disconnected), but this hasn't been explicitly tested here — flagged for Phase 7
  forward-testing rather than assumed safe.
- **No account-currency/cent-account self-check** (already established in Phase 1's
  audit) — correctness depends entirely on `.set` calibration, with no EA-level fallback
  if it's ever wrong.

### 9.3 Defense-in-depth, by layer

| Layer | Existing | Recommended addition |
|---|---|---|
| **1. EA level** | Margin check, spread gate, indicator-handle guards, magic-number lock, state persistence, exit-strategy validation, custom-string validation | Turn on `InpUseEquityProtection`; apply `InpMaxTradesPerSequence` and `InpMaxSequencesPerDirection` caps (Phase 6, using §4.6/§4.7's evidence) |
| **2. MT5/account level** | Broker-side margin call/stop-out (always active, outside the EA's control) | Confirm the actual cent account's margin-call/stop-out levels once the symbol spec is available (Phase 5) — this is the true last-resort floor if everything else fails |
| **3. Broker level** | Whatever FTMO/the cent-account broker enforces (max leverage, negative-balance protection if offered) | Confirm negative-balance protection status on the actual cent account — standard on most retail/cent accounts but must be confirmed, not assumed, per the brief's own "verify the actual broker implementation" instruction |
| **4. VPS/platform level** | None currently — this is dev-environment only | Phase 7 concern: a VPS with auto-restart-on-crash for the terminal, and ideally a dead-man's-switch/heartbeat alert if the terminal or EA stops updating (covered in Phase 8/10) |
| **5. Manual intervention** | None automated — entirely on the user | Phase 8's measurable emergency-intervention thresholds (next) give this layer objective triggers instead of "if it looks bad" |

### 9.4 Failure modes from the brief, mapped to what actually protects against them today

| Failure mode | Protected today? | By what |
|---|---|---|
| Runaway position accumulation | **Partially** | `InpMaxSequencesPerDirection=3` already caps concurrent sequences; `InpMaxTradesPerSequence` is unlimited (gap — §9.2) |
| Incorrect lot sizing | Partially | `NormalizeLot()` clamps to broker min/max/step; nothing stops a misconfigured `.set` from being economically wrong (cent-account rescale risk, Phase 1) |
| Duplicate orders | Yes | Magic-number collision lock (one live instance per Symbol+Magic); new-sequence entries are bar-gated, not tick-gated |
| Failed stops | N/A by design — no fixed stops exist; risk is structural (lot sizing + caps), not order-level | See §9.2 |
| Excessive spread | Yes | `SpreadOk()`, both entry types |
| Corrupted/missing indicator data | Yes | Fail-closed `CopyBuffer()`/`INVALID_HANDLE` guards throughout |
| EA restart / terminal restart | Yes | `SaveState()`/`LoadState()` |
| Connection loss | Assumed (MT5-native), not explicitly tested | Flagged for Phase 7 |
| Partial execution | Not specifically handled | No code found that distinguishes a partially-filled order from a fully-filled one — MT5 market orders on forex are effectively all-or-nothing in practice, but not explicitly verified here |
| Margin exhaustion | Yes | `MarginOk()` pre-trade check |
| Unexpected account-denomination behavior | **No** | Phase 1's central finding — zero EA-level cent-account awareness |

---

## Phase 8 — Emergency Intervention Rules (measurable thresholds)

Calibrated directly against Phases 2-4's real numbers, not generic rules of thumb.
Thresholds are expressed as **percentages or ratios wherever possible** (account-size-
agnostic, usable today) rather than dollar amounts, since the cent account's actual lot
sizing isn't finalized until Phase 6 — dollar-denominated versions of these same
thresholds get filled in there. Historical baseline for calibration: equity drawdown
stayed in the 0.08%-0.10% range across in-sample and both OOS windows under the
parameters actually going live (Phase 3.5); even the Monte Carlo's worst-of-20,000
pooled simulation (§4.13) only reached ~0.10%; win rate 72-76%; trade frequency ~4.5-5.3
trades/month; historical maximum single losing trade was a small fraction of average
win size (Phase 2).

### 8.1 Decision tree

```
                    ┌─────────────────────────────────────────────┐
                    │  OBSERVE (continuous monitoring, Phase 10)   │
                    └───────────────────┬───────────────────────┘
                                         │
                          any §8.2 trigger fires?
                                         │
                    ┌────────────────────┼────────────────────┐
                   NO                 WARNING              CRITICAL
                    │                    │                     │
                 CONTINUE          INVESTIGATE            immediate action
                                    (no action to           per trigger's
                                    the EA itself;           own row in §8.2
                                    confirm cause             (PAUSE /
                                    before deciding            REDUCE /
                                    anything else)              CLOSE /
                                         │                    DISABLE)
                              cause found & benign? ──YES──► back to CONTINUE
                                         │
                                        NO
                                         │
                              escalate per §8.2's row for
                              that specific trigger
```

### 8.2 Triggers, thresholds, and required action

| Signal | Normal | Warning → Investigate | Critical → act now |
|---|---|---|---|
| **Equity drawdown from peak balance** | ≤ 1% | 1%-3%: investigate, no EA change yet | **>3%: PAUSE new sequences.** **>5%: CLOSE all positions, DISABLE the EA**, then investigate. (Calibrated as ~10x-50x the worst level ever observed under these exact parameters across in-sample/OOS/Monte Carlo — hitting even the Warning band is already a genuine departure from everything tested.) |
| **Realized win rate, rolling 20-trade window** | ≥ 60% | 50%-60%: investigate | <50%: PAUSE (historical baseline is 72-76%; below-50% over 20 trades is a real behavioral shift, not noise) |
| **Trade frequency (rolling 30 days)** | 2-15 trades/month | 0 trades in >45 days (possible silent failure), or >20 trades/month | 0 trades in >90 days with the terminal/VPS confirmed running: **DISABLE and investigate** — something has silently broken. >30 trades/month: PAUSE and investigate (far outside anything backtested — could be a logic bug spamming entries, or a market regime the strategy was never validated for) |
| **Position/lot size on any single order** | Exactly matches `InpInitialLot` × the active multiplier system's value for that trade index (Phase 4.2's table) | N/A — zero tolerance | **Any mismatch at all: DISABLE immediately, investigate.** This should be structurally impossible if the EA and broker are both functioning; a mismatch means state corruption, a parallel EA instance, or a broker-side problem. |
| **Live spread (rolling observation)** | Comfortably under `InpMaxSpread` (40 pts) most of the time | Regularly observed within 10 points of the cap | Cap being hit routinely enough to visibly suppress trade frequency: investigate broker/liquidity conditions before assuming the strategy stopped working |
| **Execution slippage vs. `InpSlippage=3` pts request** | Fills at or near requested price | Any consistent (not one-off) slippage beyond the request | Repeated (3+) rejected/failed orders in a session: **PAUSE**, investigate broker/connection |
| **`OrderSend`/runtime errors in the Experts/Journal log** | None | 1 isolated error: investigate before next trade | 2+ in a rolling 24h window: **PAUSE**, investigate |
| **Connection/VPS stability** | Continuous | Any disconnection >5 min during active session: investigate on reconnect, manually verify broker positions vs. EA's internal sequence state (Phase 9's flagged gap — this is the one thing that isn't automatically verified) | 3+ disconnections in a week: escalate as a platform/VPS problem (Phase 7), not a strategy problem |
| **Margin level** | Broker-specific, confirm real numbers in Phase 5 | Below 500%: investigate | Below 300%: **REDUCE exposure** (skip new sequences). Below 150%: **CLOSE positions manually** before the broker's own stop-out forces it at a worse moment. |
| **Structural strategy-behavior check** | Concurrent sequences per direction ≤ `InpMaxSequencesPerDirection`; trades per sequence ≤ `InpMaxTradesPerSequence` (once Phase 6 applies real caps, per §9.2) | N/A — zero tolerance | Any breach: **DISABLE immediately.** Same reasoning as the lot-size row — structurally shouldn't be possible if the code and its caps are working. |
| **Divergence from tested/forward-tested behavior** | Monthly PnL run-rate within the range already seen (§3.5: ~$9-22/month equivalent, scaled to account size) | 1 month meaningfully outside that range: investigate, no action | 2 consecutive months meaningfully outside that range, or a single drawdown event exceeding the Monte Carlo's 99th-percentile estimate (§4.13): **PAUSE, full review before resuming** |

### 8.3 What "investigate" actually means

Not a vague instruction — investigating means, in order: (1) check the Experts/Journal
log for errors around the trigger time, (2) compare the actual trade/position against
what `EA_DCA_CENT_V1.mq5`'s logic predicts for that bar (the `DCA_EA_Forensic.mq5`
diagnostic build from earlier in this project exists exactly for this — it logs every
gate's pass/fail state per bar without altering trading behavior), (3) check broker
status pages/news for an abnormal market condition, (4) only resume normal operation
once a specific, named cause is identified and judged benign — never resume just because
the metric happened to recover on its own without an explanation.

---

## Phase 10 — Monitoring Checklist

Directly derived from §8.2's thresholds — same metrics, same Normal/Warning/Critical
bands, reformatted as a practical routine rather than a reference table.

### 10.1 Daily (takes ~5 minutes)

| Check | Normal | Warning | Critical |
|---|---|---|---|
| Balance vs. equity gap | Equity within 1% of balance | 1-3% gap | >3% gap (floating loss — see §8.2) |
| Today's realized P&L | Any value — single-day noise isn't itself a signal | — | A single day's loss alone exceeds the §8.2 3% drawdown band |
| Open positions match expectation | Count and total lot size match what the last known sequence state implies | Any unexplained position | Any unexplained position **and** you can't immediately trace it to a specific sequence — treat as §8.2's zero-tolerance structural-check row |
| Experts/Journal log | No errors since last check | 1 isolated error | 2+ errors |
| Terminal/VPS still running and connected | Yes | Reconnected since last check (any gap >5 min) | Currently disconnected |

### 10.2 Weekly (takes ~20 minutes)

| Check | Normal | Warning | Critical |
|---|---|---|---|
| Trade count this week | Consistent with ~1-4/week (baseline ~4.5-5.3/month) | 0 trades this week (if 0 for >6 weeks running, escalate per §8.2) | Sustained >6-7 trades/week |
| Win rate, last 20 trades | ≥60% | 50-60% | <50% (§8.2: pause) |
| Rolling equity drawdown from peak | ≤1% | 1-3% | >3% |
| Average spread observed vs. `InpMaxSpread` | Comfortably under | Regularly within 10 pts of cap | Cap routinely hit |
| Commission + swap as a fraction of gross trading P&L | Roughly consistent with Phase 2's baseline (~10% combined) | Meaningfully higher (broker/swap terms may have changed) | — |
| Margin level | Confirm real thresholds once Phase 5 completes | Below 500% | Below 300% |
| Compare actual equity curve shape to the backtest/forward-test equity curve | Broadly similar shape | Visibly diverging trend | Sharp, unexplained divergence |

### 10.3 What "normal" vs "warning" vs "critical" means in practice

- **Normal**: no action, no log entry needed beyond the routine check itself.
- **Warning**: note it (date, metric, value) somewhere durable — this plan document's
  changelog is the natural place — and watch the next 1-2 checks specifically for that
  metric. Do not change any EA parameter on the strength of a single Warning.
- **Critical**: stop and follow §8's decision tree immediately; do not wait for the next
  scheduled check.

---

## Phase 11 — Go/No-Go Decision Framework (current state)

Honest snapshot as of this point in the process — not a final go-live sign-off, since
Phase 5 (cent-account validation), Phase 6 (final production `.set`), and Phase 7
(forward testing) are still outstanding, two of them blocked on inputs only the user can
provide. Every classification below is backed by a specific phase/section above, not
asserted.

| Area | Status | Evidence |
|---|---|---|
| **Code integrity** | **PASS** | Compiles clean (0 errors/0 warnings, verified repeatedly); `EA_DCA_CENT_V1.mq5` diff-verified byte-identical to `DCA_EA.mq5` beyond its header; full dependency inventory (Phase 1). |
| **Backtest integrity** | **PASS WITH CONDITIONS** | Settings verified against each report's own Settings section every run, not just trusted logs; real commission/swap modeled (Phase 2). Condition: only ~24 months of genuine (non-synthetic) tick data exists on this account (Phase 3.1) — a permanent data-availability constraint, not a testing flaw, but it caps how much regime diversity can ever be claimed here. |
| **Strategy behaviour** | **PASS WITH CONDITIONS** | Extensively investigated this project (entry/exit logic audit, PnL-discrepancy root-cause, Finding 2 fix, validated). Condition: a small ($16.57) PnL-gap residual vs. the reference EA remains explicitly unconfirmed/undecomposed — known, documented, not blocking. |
| **Optimization robustness** | **PASS WITH CONDITIONS** | 4 one-at-a-time sensitivity sweeps completed with a sound, OOS-checked methodology (Phase 4); correctly rejected two attractive-looking-but-overfit candidates. Condition: necessarily narrow (4 parameters, one at a time) given the available data volume — broader exploration would need more live/forward-test history first. |
| **Out-of-sample performance** | **PASS WITH CONDITIONS** | Two genuinely untouched OOS windows tested (Phase 3.5); combined run-rate closely matches in-sample. Condition: one window (OOS-A) has only 19 trades — real evidence, but a small sample; total genuine OOS evidence is only ~12 months. |
| **Execution robustness** | **NOT VALIDATED** | Spread-sensitivity proven low-impact (Finding 1, Phase 4.12). But real execution quality — actual fill slippage, actual latency — has never been measured, because no live/forward-test data exists yet. Cannot be validated by backtesting alone; this is what Phase 7 is for. |
| **Cent-account compatibility** | **NEEDS INVESTIGATION** *(updated — see Phase 5)* | Real RoboForex ProCent specs now obtained (contract size unchanged at 100,000 units/lot, 0.01 lot min, 30% stop-out). Phase 5 surfaced a bigger, quantified finding than the original currency-unit concern: `InpInitialLot=0.01` is a fixed absolute size independent of account balance, so the Monte Carlo's worst-of-20,000 dollar drawdown ($98.67) would be ~66% of a $150 account vs. 0.10% of the $100,000 test account. This is a capital-adequacy decision for the user, not a code defect — tracked as the one open item blocking Phase 6. |
| **Risk management (design)** | **NEEDS INVESTIGATION** *(downgraded from PASS WITH CONDITIONS — see Phase 9's correction)* | Concrete, measurable monitoring framework built (Phase 8), but a genuine loss-based circuit breaker does not currently exist anywhere in the EA's code — `InpUseEquityProtection` was found to be a profit-lock, not a loss-stop, correcting this document's own earlier error. Applying the `InpMaxTradesPerSequence`/`InpMaxSequencesPerDirection` caps (Phase 6) helps but doesn't add an actual hard-dollar-loss ceiling. |
| **Catastrophic-loss protection** | **NEEDS INVESTIGATION** | EA-level and MT5/account-level layers audited (Phase 9). VPS/platform layer (auto-restart, heartbeat/dead-man's-switch alerting) is entirely unaddressed — genuinely a Phase 7 deployment-environment decision, not something backtesting can validate. |
| **Live monitoring readiness** | **PASS WITH CONDITIONS** | Concrete, threshold-based daily/weekly checklist built directly from real backtest calibration (Phase 8/10). Condition: never exercised against real live data — whether the thresholds are practically workable day-to-day is unverified until Phase 7. |
| **GBPUSD / second-symbol readiness** | **NOT VALIDATED** | Confirmed materially different risk profile under EURUSD-tuned parameters (Phase 3.2, profit factor 2.11 vs 5.52). No optimization or OOS validation has been run for GBPUSD specifically. |

### 11.1 What this means concretely

**Not ready to go live today.** The two hard blockers are: (1) Phase 5 cent-account
validation — needs the real `EURUSDc`/`GBPUSDc` symbol specification from you, and (2) a
production `.set` (Phase 6) actually applying the risk-management recommendations from
Phase 8/9 rather than just documenting them. Everything that *could* be done without
those two inputs has been — the optimization, robustness, and risk-framework work in
this document is real, evidence-based progress, not a placeholder.

**GBPUSD is a separate, not-yet-started validation track** and should not go live on day
one alongside EURUSD without its own pass through Phases 2-4.

**Once Phase 5 unblocks**, the remaining path is short: Phase 6 (apply the already-
identified caps + rescale any fixed-currency inputs actually turned on + build the real
`.set`), then Phase 7 (a genuine forward-test/demo period on the cent account before any
real money), which is also the only way to validate execution robustness and monitoring-
checklist practicality — no amount of additional backtesting substitutes for that.

---

## Phase 5 — Cent-Account Validation

Broker confirmed as RoboForex (`roboforex.com`) by the user. Real symbol specifications
retrieved directly from RoboForex's own published contract-specification pages and
account documentation (cited below) — not assumed.

### 5.1 RoboForex ProCent — real specifications (EURUSDc / GBPUSDc)

| Property | Value | Source |
|---|---|---|
| Account denomination | 100x the base currency — a $10 deposit shows as 1,000 US Cents. **Confirmed**: symbols carry a `-c` suffix (`EURUSDc`, `GBPUSDc`), matching what the user reported | [RoboForex Cent Account](https://roboforex.com/forex-trading/trading/cent-account/), search-confirmed suffix convention |
| Contract size (1.0 lot) | 100,000 base-currency units — **identical to a standard account**, not rescaled | [EURUSD ProCent spec](https://roboforex.com/forex-trading/trading/specifications/card/pro-cent/EURUSD/) |
| Minimum order volume | 0.01 lot (MT5) | [RoboForex Cent Account](https://roboforex.com/forex-trading/trading/cent-account/) |
| Maximum order volume | 1,000 lots | [RoboForex Cent Account](https://roboforex.com/forex-trading/trading/cent-account/) |
| Volume step | 0.01 lot | [RoboForex Cent Account](https://roboforex.com/forex-trading/trading/cent-account/) |
| Leverage | Up to 1:2000 on Cent accounts (exact per-account value must be confirmed at account opening) | [search result summary] |
| Stop Out level | **30%** margin level | [RoboForex Cent Account](https://roboforex.com/forex-trading/trading/cent-account/) — this is the real number for Phase 8's margin-level thresholds, replacing the placeholder there |
| EURUSD average spread | ~1.3 pips (13 points) | [EURUSD ProCent spec](https://roboforex.com/forex-trading/trading/specifications/card/pro-cent/EURUSD/) — comfortably under `InpMaxSpread=40` points |
| GBPUSD average spread | ~1.5 pips (15 points) | [GBPUSD ProCent spec](https://roboforex.com/forex-trading/trading/specifications/card/pro-cent/GBPUSD/) — also comfortably under `InpMaxSpread=40` |
| EURUSD swap | Long -1 pip / Short +0.25 pip | [EURUSD ProCent spec](https://roboforex.com/forex-trading/trading/specifications/card/pro-cent/EURUSD/) |
| GBPUSD swap | Long -0.4 pip / Short -0.45 pip | [GBPUSD ProCent spec](https://roboforex.com/forex-trading/trading/specifications/card/pro-cent/GBPUSD/) |
| Trading session | 00:05-23:55 (platform time) | Both spec pages above |

**Note on confidence**: these were retrieved via automated web fetch of RoboForex's own
pages, which is good primary-source evidence but was not cross-checked against a live
MT5 terminal actually connected to a RoboForex ProCent account (no such connection is
available in this environment). **Before funding a real account, re-verify these exact
numbers from within the MT5 terminal itself** (Market Watch → right-click `EURUSDc` /
`GBPUSDc` → Specification) — treat this table as strong preparatory evidence, not a
substitute for that final check.

### 5.2 The central finding: contract size is NOT rescaled — only the account's currency label is

This is the most important, and initially counter-intuitive, result of this phase.
**"100 cent lots = 1 standard lot" refers to the account balance's currency unit, not to
position size.** A `0.01` lot order on `EURUSDc` controls the exact same 1,000-unit real
notional as a `0.01` lot order on standard `EURUSD` — RoboForex's own spec page confirms
"trading conditions are equal to those for standard accounts." MT5 scales **every**
cent-account money value consistently (balance, equity, floating P&L, margin) by the
same 100x factor, so ratios (% drawdown, % of balance) come out identical whether
expressed in cents or dollars — Phase 1's original concern about the five fixed-currency
inputs (`InpStepAmount`, `InpProfitTargetCurrency`, etc.) is still completely valid on
its own terms (a literal `50.0` would mean 50 cents = $0.50, not $50, unless rescaled),
but it is **not** the biggest risk this phase found.

### 5.3 The real risk: $150 is very small relative to this EA's minimum viable position size

`InpInitialLot=0.01` is a **fixed absolute lot size** (`InpLotSizeMode=LOT_FIXED`,
`default.set`) — it does not scale with account balance at all. Every dollar-drawdown
figure measured in Phases 2-4 (e.g., the Monte Carlo's worst-of-20,000 simulated path,
§4.13: **$98.67**) is the real absolute dollar amount that specific sequence of 0.01-0.04
lot trades produced — a fact about the lot sizes traded, completely independent of
whatever balance the backtest happened to start from ($100,000, arbitrarily). **The
exact same absolute-dollar outcome would occur if the identical trade sequence played
out on a $150 account**, because `LOT_FIXED` mode doesn't know or care what the account
balance is.

Concretely: $98.67 / $150 = **65.8% of the account** — vs. the 0.10% it represented
against the $100,000 test balance. Even a single one-pip adverse move on a lone 0.01 lot
position ($0.10) is already 0.067% of $150 — comparable to or larger than this EA's
*entire* historically observed drawdown range (0.08%-0.10% typical, per §3.5) in one
pip. **This has nothing to do with cent-account mechanics or currency-unit bugs (§5.2
rules that out) — it is a structural capital-adequacy mismatch between the broker's
0.01 lot minimum (fixed, cannot go smaller) and $150 of real capital.** It would be
equally true on a $150 *standard* (non-cent) RoboForex account with the same 0.01 lot
floor. Back-solving the other direction: to make that same $98.67 worst-case represent
a comparable ~1% of equity (matching §8.2's Warning band), the account would need to be
on the order of **~$9,900** — a large gap from $150.

This is a real, quantified finding, not a reason to abandon the plan — but it is a
decision only the user can make, not one to resolve unilaterally. Four options, not
mutually exclusive:

1. **Fund the account with substantially more capital** before going live, closer to
   the ballpark computed above, so the existing validated risk profile actually applies.
2. **Deliberately treat the $150 as a bounded, fully-at-risk live-fire pilot** — accept
   that a single adverse sequence could consume a large fraction of it, explicitly
   because the point of this phase is validating real execution/behavior cheaply before
   committing more capital, not replicating the backtest's sub-1% drawdown experience.
3. **Sharply tighten the hard caps specifically for the $150 phase** — e.g.
   `InpMaxTradesPerSequence=1` (no DCA averaging at all) or `InpMaxSequencesPerDirection=1`
   — which bounds the absolute-dollar worst case much lower, at the cost of changing the
   strategy's character substantially from what was actually backtested. This is a
   capital-adequacy-driven change, not a backtest-chasing one, so it doesn't conflict
   with the "don't change parameters to improve results" principle — but it does mean
   the extensive validation in Phases 2-4 applies less directly to whatever reduced
   version actually trades.
4. **Switch `InpLotSizeMode` to `LOT_PERCENT_BALANCE`/`LOT_PERCENT_EQUITY`** so sizing at
   least auto-scales as the account grows from deposits or gains — doesn't solve the
   immediate $150-vs-0.01-lot floor problem (the broker's minimum is still 0.01 lot
   regardless of what the percentage calculation would prefer), but avoids the position
   staying fixed at an increasingly inappropriate size if the account grows later.

**This is now the single open decision blocking Phase 6.** Everything else needed to
build the production `.set` (the risk-cap values from §4.6/§4.7/§9.2, the equity
protection recommendation, the real spread/swap numbers above) is ready — Phase 6 just
needs to know which of these four directions (or what blend) to build toward.
