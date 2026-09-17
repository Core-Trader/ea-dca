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
the OOS evidence to show exactly why. This sweep is complete; the remaining §4.2
candidates (`InpMaxSequencesPerDirection`, `InpMaxTradesPerSequence`, BB period/deviation)
are still pending.
