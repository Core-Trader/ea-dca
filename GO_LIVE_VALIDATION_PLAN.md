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
