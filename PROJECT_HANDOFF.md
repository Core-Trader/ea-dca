# EA-DCA-V1.0 — Project Handoff for Claude Code Migration

**Purpose of this document:** carry forward everything already resolved in the prior conversation so a fresh build doesn't re-derive decisions or re-discover bugs that are already solved. Read this before writing any code.

---

## 1. Project Objective

Build a complete, production-quality **Dollar-Cost-Averaging (DCA) Expert Advisor** for MetaTrader 5, called **EA-DCA-V1.0**, from a set of supporting materials that describe the intended behavior but do not include the actual trade-management source code:

- Three custom indicators the EA depends on (`QMP_Filter.mq5`, `MACD_Platinum.mq5`, `QQE_Adv.mq5`)
- One stock indicator, unused in the final design (`BB.mq5` — native `iBands()` is used instead)
- `default.set` — the canonical list of every input parameter name and default value
- `EA_User_Guide.docx` — the full prose behavioral specification (authoritative source for any ambiguity)
- `DCA_EA_Walkthrough.docx` — a shorter narrative covering the same ground, lower priority than the User Guide

**Core mechanic:** the EA watches for a QMP Filter "dot" (a MACD+QQE sync signal) gated by a Bollinger Band and/or QQE zone breach, opens a position, and — if price moves further against it — adds more positions (the DCA "sequence"), scaling size by a configurable multiplier system. Each sequence exits as a whole, via one of six configurable Exit Strategies, with several advanced overlays (Dynamic Stop, Partial Close, Risk Reduction, Recovery Mode).

**Explicitly stated non-negotiable requirement:** deterministic, reproducible backtest behavior. This ended up being the central challenge of the whole project — see §4.

---

## 2. Key Design Decisions Already Resolved

These were worked through carefully against the guide and should be treated as settled unless you find a specific reason to revisit them:

1. **QMP Filter's own `HigherTimeFrame` input** is legacy/visual only, not used by the main EA. The Higher Timeframe Direction Filter is implemented independently, checking BB/QQE on the higher timeframe directly.
2. **`InpFibSequence`** — kept this exact name from `default.set` (not renamed), but retyped from a numeric field to a **string** holding a CSV multiplier sequence (e.g. `"1,3,5,8,13"`), since that's what it actually needs to hold for the Custom multiplier system.
3. **`InpTrailingStepPips`** — confirmed this is the **Trailing Distance** field (not a step-granularity field); name kept as-is to match `default.set` exactly despite being a slightly confusing name. `InpTrailingStepBlockPips` is the separate step-granularity field.
4. **`InpPartialClosePercent`** — a 2-value enum (`None` / `50%`), with `50%`'s underlying integer value explicitly set to `50` (not `1`) so it still imports correctly from a `default.set` file that has `InpPartialClosePercent=50`.
5. **Bollinger Bands**: use native **`iBands()`**, not the supplied `BB.mq5` file. No indicator-file dependency for BB.
6. **Every dropdown-style input** should be a real enum (native MQL5 enum where one exists — `ENUM_APPLIED_PRICE`, `ENUM_MA_METHOD`, `ENUM_LINE_STYLE`, `ENUM_TIMEFRAMES` — or a custom one otherwise), not a raw `int`.
7. **Hedging vs. netting account mismatch**: soft warning only (`Print`, not `Alert`), does not block `OnInit()`. The whole sequence-tracking design assumes hedging (independent tickets per trade); netting accounts will behave differently but the EA should still run.
8. **Magic Number collision** (same Symbol+Magic combination already in use by another chart): **hard fail** (`INIT_FAILED`). Treated more strictly than the hedging mismatch because a collision risks silently corrupting sequence tracking, not just changing trading behavior.
9. **State persistence format**: a flat, pipe-delimited **text** file under `MQL5/Files/` (MQL5 has no native JSON support, and hand-rolling a JSON parser wasn't worth the complexity for this). Only "soft" state that can't be reconstructed from live positions is persisted (locked base lot, recovery/trailing/partial-close flags, last-entry time/price); ticket lists are saved, but `avgPrice`/`volume`/`count` are always **reconstructed from live positions on load**, never trusted from the file — positions can close outside the EA's control (manual intervention, broker stop-out) and the file could be stale.

**Multiplier System labels** (for the dropdown): Safe (Delayed Fib) `1,1,1,2,3,5,8` / Linear (Arithmetic) `1,2,3,4,5,6,7` / Classic Fibonacci `1,2,3,5,8,13` / Aggressive (Lucas) `1,2,4,6,10,16` / Martingale `1,2,4,8,16,32` / Custom (uses the CSV string field).

**Branding**: `EA-DCA-V1.0` throughout (copyright property, version property, default trade comment).

---

## 3. Critical Bugs Already Found and Fixed — Do Not Reintroduce These

These cost significant debugging time and should inform the fresh build's design from the start, not be re-discovered:

1. **Partial Close must not touch a lone remaining trade.** The guide is explicit: if a sequence has only 1 trade when Partial Close fires, the EA does *not* close or reduce it — just attaches a breakeven (+ optional trailing) stop. The 50%-reduction only applies when the sequence had ≥2 trades to begin with.

2. **A QMP dot appearing *before* the entry zone arms must not be discarded.** The guide explicitly describes this as valid, with no time limit ("a few candles later there is a breach... that previous QMP dot is still a valid trade signal"). The signal needs to persist across bars until the zone arms, superseded only by a newer dot. Any filter that inspects "the signal candle" (e.g. a centre-band-breach check) needs to capture that state *at the moment the dot is recorded*, not re-derive it later from whatever bar happens to be current.

3. **MQL5 requires a true compile-time constant for a static array size** — a local `const int` is *not* sufficient and throws "invalid index value" at compile time. Use `#define` or a literal for any array dimension.

4. **State persistence must be explicitly disabled inside the Strategy Tester.** Files written via `FileOpen()`/`FileWrite()`, and Global Variables written via `GlobalVariableSet()`, both **persist across separate backtest runs** of the same EA on the same symbol within one terminal session. Without an `if(MQLInfoInteger(MQL_TESTER)) return;` guard in every save/load function, a "fresh" backtest silently inherits state from wherever the *previous* run happened to end — corrupting results in ways that are very hard to diagnose after the fact.

5. **The most important one: `OnInit()` must explicitly reset every single piece of EA state at the very start**, not rely on the assumption that global variables start fresh on every run. The Strategy Tester can reuse the same loaded module across consecutive runs in one session, meaning the actual global data segment — including full sequence-tracking arrays — can carry over from the end of one run into the start of the next. This was the root cause of the worst symptoms encountered: wildly inconsistent trade counts and, in the worst cases, catastrophic runaway losses (a leftover phantom sequence's stale ticket number coincidentally matching a *real* ticket in a new run, since backtest ticket numbering restarts low each time, silently corrupting that sequence's average price and exit target from the first trade). **Write an explicit `ResetGlobalState()` and call it as literally the first line of `OnInit()`**, covering every global including the sequence arrays, before doing anything else — including before loading any persisted state.

---

## 4. The Unresolved Issue That Motivated This Restart

**Symptom:** even after fixing all of §3, backtest results for exit strategies that use **Recovery Mode** (BB Centre Band, BB Opposite Band non-forced, QQE 50+Recovery) still showed meaningful run-to-run variance — not catastrophic anymore, but enough to make settings comparisons unreliable without averaging multiple runs.

**Leading hypothesis — well-supported, but NOT confirmed by a clean controlled test. Read this before trusting it.**

The investigation went through several theories, in order, most tested and disproven before landing here:

1. Tester "Random delay" simulation — disproven (zero-latency/ideal execution was already active).
2. Incomplete real-tick history caching — disproven (100% tick quality, consistent history confirmed).
3. Tick-tie ordering (same-millisecond ticks resolved differently between runs) — proposed, then contradicted by MetaQuotes' own documentation ("no simulation is performed" in real-tick mode), and abandoned.
4. **Recovery Mode's per-tick check as the sole cause — tested directly by switching to First Profitable Close (zero per-tick logic) and appeared to be DISPROVEN**: that exit strategy also showed large variance (76 vs 38 net profit on identical settings). Treated as disproving the theory at the time.
5. That First-Profitable-Close test led to discovering the real, dominant bug: uninitialized globals (§3 item 5) — fixed. But **the First Profitable Close test was never re-run after that fix.** Its earlier variance is very plausibly fully explained by the global-reset bug rather than anything tick-related — but this was never confirmed. That's the missing control.
6. After the global-reset fix, testing moved to BB Centre Band (a Recovery-Mode strategy) and still showed variance, including under 1-Minute OHLC mode (zero tick-level ambiguity). This is where the current hypothesis comes from: OHLC bar data doesn't record whether a bar's High or Low occurred first, and Recovery Mode's live "if price then hits that level" check is the one place in the EA sensitive to that ambiguity.
7. **Independently corroborated** (not proven, but a real point in its favor) by an uploaded reference commercial EA (`_0_JFX_DCA_Type_V_v1_Money.mq5`) implementing a structurally identical QQE-entry/QQE-recovery-exit strategy, whose default behavior uses the exact same live-polling architecture — confirming this is a known characteristic of "EA-managed TP" logic in MQL5 generally, not something specific to this codebase.

**The gap that should be closed before trusting this diagnosis**: re-run First Profitable Close (or any non-Recovery-Mode strategy) under OHLC mode, now that the global-reset fix is in place. Bit-identical results across repeats would isolate the remaining variance to Recovery Mode specifically. Continued variance would mean another bug remains, unrelated to Recovery Mode. **This test was never run. Run it before committing significant new work to the fix below.**

**The fix that was scoped but never implemented — recommended, with one important caveat:**

Instead of polling live price in EA code and manually closing when a target is reached, **set the target as a real broker-side position TP via `trade.PositionModify(ticket, 0, targetPrice)`**, and let MT5's own dedicated stop-order simulation engine trigger it. That engine is documented to have well-defined behavior for whether a bar's High/Low crossed a given level, in every tester mode including OHLC — a fundamentally more robust code path than EA-side polling, and it's the same pattern the reference commercial EA offers as its professional-grade option.

**The caveat**: this recommendation itself rests on an *unverified* assumption — that MT5's broker-side SL/TP simulation is deterministic across all three tester modes for this specific use case. That assumption has never been empirically tested in this project. It's a reasonable belief (a far more standardized code path than arbitrary `OnTick()` logic), but "more standardized" is not the same as "verified" — and an unverified platform assumption is exactly what caused the largest bug in this project (§3 item 5). **Before building the exit-architecture around this, write a minimal throwaway EA that only opens one position and sets a fixed TP, and run it 3x each in OHLC, every-tick, and every-tick-real-ticks mode. Confirm bit-identical results before treating broker-side TP as a solved foundation.** This costs almost nothing and directly avoids repeating the same category of mistake with a new mechanism.

This is **not a trivial substitution even if the assumption holds** — it has real architectural consequences that should be designed in from the start rather than retrofitted:

- A "sequence" can hold multiple tickets, but MT5 has no basket-level TP — the same price has to be set on **every open ticket** in the sequence, and re-set on every ticket whenever a new trade is added (since new adds shift `avgPrice`, which shifts the target).
- Broker-side stop-distance rules (`SYMBOL_TRADE_STOPS_LEVEL`) now apply, and can reject the modify if price is already very close to the target when it's set — needs a retry-or-fallback path, not just a bare `PositionModify()` call.
- Positions can now close **outside the EA's own code path** (the broker triggers it directly). All the bookkeeping that currently assumes "we always initiate our own closes" (re-entry-latch resets, Session Profit Limit accounting, chart-object cleanup) needs to detect an externally-triggered close via the position-sync logic and route it through the same cleanup, rather than only running when the EA calls `PositionClose()` itself.
- This pattern only fully applies to **fixed-target-style exits** (Recovery Mode, Risk Reduction, Fixed Target). **Continuously-trailing** mechanics (Dynamic Stop, Pure Trailing Stop) would need repeated `PositionModify()` calls as price moves favorably — worth throttling (the reference EA has dedicated `TrailUpdateStepPip`/`TrailUpdateStepSeconds` inputs for exactly this) rather than calling it every tick.
- Only meaningful on hedging accounts (already the project's standing assumption throughout).

**Recommendation for the rebuild**: verify the broker-side-TP determinism assumption first (see above), then design the exit-strategy layer around it for anything with a "hits that level" semantic, rather than building an EA-side polling version first and converting later.

---

## 4a. Process Pitfalls — What Not to Repeat

These are lessons about *how the debugging happened*, not just what the bugs were. They matter more than the specific fixes, because they'll cause new problems in new code if repeated.

1. **Never assume MQL5/Strategy Tester state resets automatically between runs — of any kind.** Not global variables, not files, not Global Variables, not indicator handles. This assumption was wrong twice in this project (file/Global-Variable persistence, then the much larger un-reset-globals bug) at increasing cost each time. Explicitly initialize and explicitly guard everything, as standing practice from the first line of code — not as a retrofit after strange results appear.
2. **Don't diagnose backtest nondeterminism by sequentially guessing at exotic tester-internals theories from aggregate P&L/trade-count numbers.** This project went through five theories (random delay, tick completeness, tick-tie ordering, Recovery-Mode-specific, bar-boundary ambiguity) before finding the dominant real cause. Build a minimal, fully controlled reproduction *first*: simplest possible configuration (simplest exit strategy, no optional filters, small date range), confirm it is perfectly deterministic as a baseline, then add one mechanic at a time until variance reappears. That isolates the cause in one pass instead of many.
3. **Treat any "hits a level" exit/stop mechanism (Recovery Mode, Risk Reduction, Dynamic Stop, Pure Trailing, Fixed Target pips/ATR) as suspect by default if implemented via EA-side polling of live Bid/Ask.** This is the one architectural pattern implicated in the unresolved variance, and it's shared by five different mechanics in the current code, not just Recovery Mode.
4. **An assumption about *new* platform behavior (e.g., broker-side TP determinism) deserves the same scrutiny as the assumption that caused the biggest bug here.** Verify it directly with a minimal test before building on it — see the caveat above.
5. **"No error in the Journal" and "100% tick quality" rule out specific failure modes, not the category of failure.** Don't treat either as proof of full determinism.

---

## 5. Files to Bring Into the Claude Code Project

All of these have been copied into a single output bundle alongside this document.

| File | Type | Purpose | Notes |
|---|---|---|---|
| `default.set` | Config | **Ground truth** for every input parameter's name and default value. | Treat as non-negotiable except for the explicitly-approved renames in §2 (items 2-4). |
| `EA_User_Guide.docx` | Documentation | **Authoritative** behavioral specification — every input explained, with the subtle rules (Recovery Mode's "no time limit," Partial Close's single-trade exception, the guide's own language on locked base lot per sequence) that are easy to miss on a skim. | Primary source for resolving any ambiguity. |
| `DCA_EA_Walkthrough.docx` | Documentation | Shorter narrative covering the same settings; useful for confirming section grouping/order. | Lower priority than the User Guide; adds little beyond it. |
| `QMP_Filter.mq5` | Custom indicator | Generates the entry-trigger "dot" by combining MACD_Platinum + QQE Adv. | Must be placed in `MQL5/Indicators/` with this exact name — the EA calls it via `iCustom(..., "QMP Filter", ...)`. |
| `MACD_Platinum.mq5` | Custom indicator | "Zero-Lag MACD," used internally by QMP Filter only. | The main EA never calls this directly. Still needs to be in `MQL5/Indicators/` since QMP Filter depends on it. |
| `QQE_Adv.mq5` | Custom indicator | Modified-RSI oscillator. Used two ways: internally by QMP Filter (fixed params) *and* directly by the main EA as a standalone entry-zone/exit indicator (user-configurable params, default SF=7/RSI=14/WP=1). | Must be in `MQL5/Indicators/`. |
| `BB.mq5` | Stock indicator | Bollinger Bands — **not used** in the current design (native `iBands()` preferred, per §2 item 5). | Reference only; safe to omit entirely from a fresh build. |
| `_0_JFX_DCA_Type_V_v1_Money.mq5` | Reference EA (third-party, machine-generated) | A commercial "EA Builder Pro" output implementing a structurally comparable QQE-entry/QQE-recovery-exit strategy. Directly informed the §4 diagnosis and recommended fix (its `SendSlTpToBroker` pattern). | Large (9,000+ lines), generic/auto-generated architecture, not meant to be copied from directly — useful specifically for its QQE indicator usage pattern and its broker-side TP/SL implementation (search it for `SendSlTpToBroker`, `PositionModify`, `IsClosePriceTPHit`). |
| `DCA_EA_Analysis_Report.md` | Project document (produced during this project) | The living analysis document: full parameter table, architecture diagram, the §2 decisions log with full reasoning, risk/compatibility notes. | Recommend bringing in as-is — it captures a large amount of already-resolved ambiguity that would otherwise need to be re-derived from the `.docx` files from scratch. |
| `DCA_EA.mq5` | Prior implementation (~2,700 lines) | A substantially complete build: full input block, indicator handles, `OnInit()` validation, the full entry pipeline, all six Exit Strategies, Dynamic Stop, Partial Close, Risk Reduction, entry-side filters (BB Width, Centre Band Cross, Signal Distance, MA Filter, HTF Direction Filter, All-Signals-Match-Entry), session/EOD/EOW handling, state persistence, and on-screen display — with all five §3 bug fixes already applied. | **Recommend as a reference, not a starting file to build on top of as-is.** Its known architectural gap is exactly §4 (EA-side tick-polling for Recovery Mode/Risk Reduction/Dynamic Stop/Pure Trailing). Useful for the ~90% of the logic that has nothing to do with that gap (input block, entry pipeline, all the entry-side filters, state persistence, display) — either refactor its exit-check layer specifically, or use it as a line-by-line reference while writing fresh files structured around broker-side SL/TP from the start. |
| `PROJECT_HANDOFF.md` | This document | Consolidates everything above into one file to carry into the new project so this context isn't lost on restart. | — |

---

## 6. Suggested Next Steps in Claude Code, in Order

1. **Close the diagnostic gap first** (§4): run First Profitable Close under OHLC mode, 3x, now that the global-reset fix exists. This determines whether §4's diagnosis is actually correct before anything is built around it.
2. **Verify the proposed fix's own assumption** (§4): the minimal single-position, fixed-TP test across all three tester modes, described above.
3. Only after both of those come back clean: design the sequence/position-tracking data model **around** broker-side SL/TP from the outset (deciding how a multi-ticket sequence's shared target gets kept in sync, and how externally-triggered closes get detected and routed through the same cleanup bookkeeping) — before porting over the entry pipeline, filters, and other logic from `DCA_EA.mq5`, which can mostly come across with only the exit-check layer needing to change.

If step 1 or 2 comes back *not* clean, stop and re-diagnose rather than proceeding to step 3 — that would mean building the new architecture on the same kind of unverified assumption this whole handoff is trying to help you avoid.
