# DCA_EA.mq5 — Full Source Audit

**Scope:** entire current `src/experts/DCA_EA.mq5` (2,916 lines), read top to bottom line-by-line. No code changes made — this is findings only, per the request that prompted it.

**How to read this report:** findings are split into three tiers by confidence, matching what was asked for:
- **A. Definite defects** — confirmed by reading the code; the behavior is provably wrong or inconsistent with the EA's own stated design, independent of any comparison to the reference EA.
- **B. Potential risks / design concerns** — real code paths worth worrying about, but whether they're "wrong" depends on intent that isn't fully pinned down, or the trigger condition is narrow/rare.
- **C. Untested-against-reference surface area** — code that compiles and runs but has **never been exercised in any backtest in this project**. Every test run to date used `InpExitStrategy=EXIT_BB_CENTRE_BAND`, `InpLotSizeMode=LOT_FIXED`, and left most filters off. This is likely the largest source of undiscovered behavioral divergence, simply because it's never been looked at.

Section D turns all of this into a prioritized test plan.

---

## A. Definite defects

### A1. `InpBBExitOnBreach` is a dead input — declared, documented, never read
**Location:** input declaration at line 163; only referenced in three code *comments* (lines 1964, 2194, 2197), never in actual logic.
**Severity: High.** The input's own doc string says "Exit on Breach, Not Just Close (BB Centre Band Exit)" — a user toggling this in the Inputs tab reasonably expects it to change behavior. It does nothing. This happened as a side effect of the §13/§14 forensic fix: the touch-based exit variant (`BBCentreExitConditionTick`) was removed when evidence showed the reference is bar-close-driven, but the input that used to select between the two variants was left in place instead of being removed or re-wired.
**Fix direction (not applied):** either remove the input entirely (breaking `default.set` compatibility — same class of decision as the historical `InpFibSequence` retype) or restore a real touch-based code path for `=false` and validate it against the reference before shipping either choice.

### A2. Orphaned position on a failed `PositionClose()` in `CloseSequenceAndCleanup()`
**Location:** lines 2012–2037.
```
for(int i = 0; i < count; i++)
  {
   ulong ticket = ...
   if(PositionSelectByTicket(ticket))
     {
      if(!trade.PositionClose(ticket))
         Print("EA-DCA: failed to close ticket ", ticket, " ... ");   // logged, nothing else
     }
  }
...
RemoveSequenceAt(isBuy, idx);   // unconditional
```
**Severity: High (low-to-moderate likelihood).** If `PositionClose()` fails for any leg (requote, temporary broker rejection, connectivity blip, "trade context busy"), that leg's position stays open in the market, but `RemoveSequenceAt()` runs anyway and drops the *entire* sequence from tracking — including the still-open leg. That position becomes permanently invisible to the EA: `PruneClosedSequences()` only iterates *currently tracked* sequences, so it can never rediscover an orphan. The position then has no exit management, no stop-loss, indefinitely — exactly the scenario the whole EA's risk model depends on preventing. A secondary effect: `g_sessionRealizedProfit` is credited with the *entire* pre-close floating value of the sequence (captured before any close attempt), so the untouched leg's P/L gets counted as "realized" against the Session Profit Limit even though it's still just floating.
**Contrast:** `ExecutePartialCloseIfDue()` (§A-adjacent, see B3) handles this more safely — it calls `SyncSequenceFromLivePositions()` immediately after its close attempts, which re-reads what's *actually* still open and would keep a failed-to-close leg correctly tracked. `CloseSequenceAndCleanup()` has no equivalent safety net.

### A3. `HandleBBOpposite()`'s breakeven check is still live-tick-driven — the exact bug class §14 fixed elsewhere, left unfixed here
**Location:** line 2261, compare against `HandleBBCentreOrQQE50()` line 2228.
```
// HandleBBOpposite (BB Opposite Band strategy):
if(GetSequenceProfitPips(isBuy, idx) >= InpBreakevenBufferPips)   // GetSequenceProfitPips = LIVE bid/ask

// HandleBBCentreOrQQE50 (BB Centre Band / QQE50+Recovery strategies), post-§14 fix:
bool atBreakeven = GetSequenceProfitPipsFromClose(isBuy, idx) >= InpBreakevenBufferPips;   // bar-close
```
**Severity: High.** §14 was the single largest fix in this project's entire forensic history (Profit Factor 2.63→4.02) — root-caused to Recovery Mode's breakeven+buffer check using live/intrabar price instead of bar-close. `DCA_EA_Analysis_Report.md` §5.7 states this same Recovery Mode mechanism "applies to BB Centre, BB Opposite, and QQE50+Recovery exits" — one shared mechanism, three strategies. The fix was applied only to the function two of those three strategies share (`HandleBBCentreOrQQE50`). `HandleBBOpposite()` — used only by `EXIT_BB_OPPOSITE_BAND`, never exercised in any backtest in this project — still uses the pre-fix live-price check, and its own exit *condition* (`BBOppositeExitCondition()`, line 1980) also reads live bid/ask at shift=0, never touched by the bar-close work at all. If BB Opposite Band is ever used, it likely carries the identical bug §14 fixed, undetected because nothing has ever tested it.
**This is the single highest-value item in this whole audit for the reference-EA comparison plan (see D1).**

### A4. Partial-close profit double-count on a failed leg close
**Location:** `ExecutePartialCloseIfDue()`, lines 2128–2175.
`closedProfit` is summed from each leg's floating P/L *before* `trade.PositionClose(ticket)` is called, with no check of its return value. `SyncSequenceFromLivePositions()` afterward correctly keeps a failed-to-close leg tracked (no orphan, unlike A2) — but its pre-close floating profit has already been added to `g_sessionRealizedProfit`, and will be added *again* whenever that leg genuinely closes later through some other exit path. Distorts the Session Profit Limit counter only; does not orphan a position.
**Severity: Low** (narrow trigger — a close failure specifically during Partial Close — and the consequence is limited to one internal counter, not P&L or risk exposure).

### A5. `g_prevCentreSide` is not persisted, and has no historical warm-up — unlike every analogous piece of state
**Location:** global declared at line 392; absent from both `SaveState()` (lines 1449–1479) and `LoadState()` (lines 2471–2569); absent from `InitializeZoneLatchesFromHistory()` (lines 759–790).
**Severity: Moderate.** Two related gaps in the same variable:
1. **Not persisted.** `g_centreCrossReadyBuy`/`g_centreCrossReadySell` (the latch it drives) *are* saved/loaded, but the raw "which side was the previous bar on" memory that arms them is not. After any live/demo EA restart, the crossing detector forgets its history and needs to observe a fresh transition before it can arm anything — a genuine cross that straddles the restart is silently missed. Backtests are unaffected (they never restart mid-run).
2. **No historical warm-up.** The zone-breach latches (`g_bbBuyArmed` etc.) get `InitializeZoneLatchesFromHistory()` — a deliberate, documented fix (§5.3/§11) for exactly this class of problem, because a cold-start default caused a real, evidenced entry-timing bug. `g_prevCentreSide` gets no equivalent treatment: it starts at `0` on every fresh run, so `CentreCrossReady()` cannot detect any cross until at least two bars into the test. Whether the reference EA's equivalent mechanism (if it has one) has the same cold start, or pre-seeds from history the way zone latches do, is unverified — and §5.3's entire investigation exists precisely because an untested cold-start assumption turned out to be wrong once.

---

## B. Potential risks / design concerns

### B1. `HandleFirstProfitable()` closes on literally any floating profit above $0.00, checked every tick
Line 2269: `if(GetSequenceProfitMoney(isBuy, idx) > 0.0)`. No buffer, no minimum, live price, every tick. Every other exit strategy in this EA has some buffer concept (breakeven+buffer, a trail distance, a fixed target). Whether this strategy is genuinely meant to be this tight, or the name implies "first *meaningfully* profitable," is not specified anywhere and has never been tested.

### B2. Risk Reduction is not scoped to any particular Exit Strategy
`CheckSequenceExitPerTick()` (lines 2366–2387) checks Risk Reduction *before* dispatching to whichever strategy `InpExitStrategy` selects — meaning it can fire under Fixed Target, Pure Trailing, First Profitable, and BB Opposite Band, not just BB Centre Band/QQE50+Recovery the way Dynamic Stop and Partial Close are restricted (§5.4's compatibility matrix has no equivalent row for Risk Reduction). This may be correct — the code's own comment flags it explicitly as an unconfirmed **assumption** — but it's worth deciding deliberately rather than by default.

### B3. Dynamic Stop arm/disarm price-source asymmetry
Arming (`HandleBBCentreOrQQE50` → `ArmDynamicStopIfDue`) is bar-close-gated as of §24. Disarming (`ManageActiveTrailStop`, line 2083: `GetSequenceProfitPips(...) <= 0.0`) is live-tick. So the stop can only arm on a confirmed bar close but can disarm on a single noisy intrabar dip. Unverified against the reference — could be intentional (protect against transient spikes by requiring confirmation to arm, but react fast to protect against transient spikes by disarming immediately) or could be an oversight from the same class of bug §14/§24 already fixed twice elsewhere.

### B4. Equity Protection is deliberately blunt — accepted trade-off, re-flagged for completeness
`CheckEquityProtection()` closes *every* sequence in *both* directions the instant combined floating profit crosses the threshold, including sequences nowhere near their own exit condition. This was discussed and accepted during design (§25) — re-listed here only so this audit is a complete picture of every mechanism that can force a close outside its own local logic, alongside B2 and A3.

### B5. State file has no format-version marker
`SaveState()`/`LoadState()` communicate their field layout only through matching hand-written comments ("field order: ... must match exactly"). The format has already changed at least once in this project's history. A future field-layout change with no version tag has no runtime protection against silently misreading an old-format file after an update — degrades gracefully field-by-field (a short line just gets skipped) rather than crashing, but wrong values could load without any signal that something's off.

### B6. Margin/account-state check-then-act gap (live/demo only)
`MarginOk()` reads live free margin, but there's a small window between checking it and `SendMarketOrder()` actually sending, during which another source (manual trade, a different EA, a broker-side stop-out) could change account state in a live/demo environment. Not realistically preventable without a broker-side lock; not a bug, just a standard limitation worth naming.

---

## C. Untested-against-reference surface area

Every item below **compiles and would run**, but has never appeared in any backtest in this project. `default.set`'s values are all "off"/simplest-option for these, which is exactly why they've stayed untested. Grouped by how much a divergence here would matter.

### C1. Exit strategies (highest impact — changes which trades close, when, and at what price)
- `EXIT_BB_OPPOSITE_BAND` (`HandleBBOpposite`) — see A3, already flagged as *likely* buggy, not just untested.
- `EXIT_FIRST_PROFITABLE` (`HandleFirstProfitable`) — see B1.
- `EXIT_FIXED_TARGET` (`HandleFixedTarget`) — three sub-modes (`TARGET_CURRENCY`/`TARGET_PIPS`/`TARGET_ATR`), none exercised.
- `EXIT_PURE_TRAILING` (`HandlePureTrailing`) — independent trailing mechanism, pips-vs-dollar start race, ATR-based start/distance variants, step-block granularity — none exercised.
- `InpBBExitOnBreach=false` — moot per A1 until that input is either wired up or removed.
- Risk Reduction (`InpUseRiskReduction=true`) — entirely untested at any `InpRiskReductionMinTrades`/`InpRiskReductionBufferPips` setting.
- Partial Close (`InpUsePartialClose=true`) — the whole feature, including the 1-trade-remaining-applies-breakeven-directly path and the 50%-of-survivor reduction path, has never run in a backtest.

### C2. Position sizing (changes lot sizes on every single trade — compounds across a whole test)
- `LOT_PERCENT_BALANCE` / `LOT_PERCENT_EQUITY` — margin-based sizing formula is an explicit, documented **assumption** (no spec formula given).
- `LOT_STEP_BALANCE` / `LOT_STEP_EQUITY` — step formula likewise assumed.
- `MULT_SAFE` / `MULT_FIBONACCI` / `MULT_AGGRESSIVE` / `MULT_MARTINGALE` / `MULT_CUSTOM` multiplier systems — only `MULT_LINEAR` (default.set's value) has ever been exercised.
- `InpMaxInitialLot` cap interacting with step-based sizing — untested combination.

### C3. Entry filters (changes *which* signals become trades — silent divergence is easy to miss since the EA still "runs")
- `InpUseBBWidthFilter` / `InpBBMinWidthPercent` — formula is an explicit assumption, never tested.
- `InpUseMinimumSignalDistance` (pips and ATR variants) — never tested.
- `InpUseMAFilter` (both `MA_BUY_ABOVE_SELL_BELOW` and `MA_BUY_BELOW_SELL_ABOVE`) — never tested.
- `InpTradeInHigherTFDirection` — bias formula is an explicit assumption (BB-middle / QQE-vs-50 on the HTF), never tested.
- `InpAllSignalsMatchEntryCriteria` — forces max 1 sequence/direction and requires a fresh zone breach for every add-on, not just a QMP dot; never tested.
- `InpRequireBBBandTouchForReentry` / `InpRequireQQEScenarioBForReentry` — re-entry-after-close gating, never tested.
- `InpTradeDirection` = Buy Only / Sell Only — only `DIRECTION_BOTH` tested.
- `INDICATOR_QQE_ONLY` mode entirely — every test used `INDICATOR_BB_ONLY`. The QQE-only entry path, and the "Both" mode's AND-gate between BB and QQE breaches, are unexercised.

### C4. Session / risk controls
- `InpUseTimeFilter` with a genuinely restrictive window (only structurally self-tested in Phase 4, not against the reference).
- `InpUseEOD` / `InpUseEOW` — all four `ENUM_EOX_ACTION` values, only structurally self-tested.
- `InpStopAfterProfitPerSession` — the "session = one calendar day" definition is an explicit assumption.
- Equity Protection at any threshold other than the one now-verified value (0.6%) — different % values, and the `EQUITY_PROTECT_AMOUNT` (flat currency) mode, are unverified.
- Netting-account behavior (`CheckHedgingAccount()`'s warning path) — never actually run on a netting account to observe what really happens.

### C5. Parameter/edge-case handling
- `InpMaxSpread=0` (disabled) vs. a genuinely restrictive value under real spread widening.
- `InpMaxTradesPerSequence>0` (capped) — only `0` (unlimited) tested.
- `InpMaxSequencesPerDirection` values other than 3.
- Broker instruments with 3-digit or non-fractional pip quoting (pip-size doubling logic, line 2848, only ever exercised on 5-digit EURUSD).
- A genuine `MarginOk()` rejection actually happening (always had ample margin in every test).
- A genuine `OrderCalcMargin()` or `PositionClose()` failure (A2/A4's trigger conditions — never observed, only reasoned about from the code).

---

## D. Reference-EA equivalence test plan

Ordered by where a small implementation difference would most change trading results, per the request. For each: what to compare, and how.

### D1. **Priority 1 — BB Opposite Band exit timing** (validates/refutes A3)
**What to compare:** for a sequence closed by BB Opposite Band, the exact close price and close time (bar) against the reference's equivalent close.
**How:** switch `InpExitStrategy=EXIT_BB_OPPOSITE_BAND`, `InpIndicatorMode` = BB or Both, run both EAs over the same window, and check whether the reference's close price is the *live touch* price or the *prior bar's close* — exactly the same diagnostic method already used for §13/§14 (dump bar High/Low/Close and the reference's actual fill price for a representative sequence). If the reference is bar-close-driven here too, A3 is confirmed and the fix is a direct port of the §14 pattern into `HandleBBOpposite()`.

### D2. **Priority 1 — Risk Reduction's strategy scope** (validates/refutes B2)
**What to compare:** with Risk Reduction enabled, does the reference apply it only under BB Centre Band/QQE50+Recovery, or under every exit strategy?
**How:** enable `InpUseRiskReduction=true` alongside `InpExitStrategy=EXIT_FIXED_TARGET` (or any non-BB-Centre/QQE strategy) in both EAs; confirm whether the reference ever closes a sequence early via Risk Reduction under that strategy at all.

### D3. **Priority 1 — Partial Close, full behavior** (currently 0% tested)
**What to compare:** trade count, which specific tickets close vs. which survive, and the exact survivor's stop level, for a sequence that triggers Partial Close with (a) exactly 2 trades and (b) 5+ trades open, at both `PARTIAL_CLOSE_NONE` and `PARTIAL_CLOSE_50`.
**How:** `InpUsePartialClose=true`, `InpUseDynamicStop=false` (mutually exclusive), run a window containing at least one multi-leg sequence that reaches breakeven+buffer; diff deal logs leg-by-leg.

### D4. **Priority 2 — Dynamic Stop arm/disarm price source** (validates/refutes B3)
**What to compare:** the exact tick/bar at which a Dynamic Stop disarms after profit falls to ≤0 — does the reference require a bar close the same way it now requires one to arm, or does it react on the same tick like the current code?
**How:** construct (or find in existing data) a sequence where profit oscillates around zero shortly after Dynamic Stop arms; compare disarm timing tick-for-tick if tick-level reference data is available, bar-for-bar otherwise.

### D5. **Priority 2 — Lot sizing modes** (compounds silently across an entire test if wrong)
**What to compare:** the exact lot size computed for trade #1 of a new sequence, for each of `LOT_PERCENT_BALANCE`, `LOT_PERCENT_EQUITY`, `LOT_STEP_BALANCE`, `LOT_STEP_EQUITY`, at a known account balance/equity.
**How:** single-trade diagnostic (open one sequence, log the computed lot, compare to the reference's lot for the identical account state) — cheaper than a full backtest and isolates the formula directly, the same pattern used for the position-sizing verification already done for `LOT_FIXED`.

### D6. **Priority 2 — Multiplier systems** (`MULT_SAFE`/`FIBONACCI`/`AGGRESSIVE`/`MARTINGALE`/`CUSTOM`)
**What to compare:** the lot size sequence across a 5+ trade sequence for each system.
**How:** these are pure, static arrays (no live-state dependency) — a table comparison against the guide's worked examples (already partially done for the array *values* themselves in the original spec extraction) plus one real backtest per system to confirm the *reuse-last-value-beyond-array-length* behavior matches.

### D7. **Priority 2 — Entry filters, each in isolation**
**What to compare:** which signals become trades, filter by filter.
**How:** enable exactly one filter at a time (`InpUseBBWidthFilter`, `InpUseMinimumSignalDistance`, `InpUseMAFilter`, `InpTradeInHigherTFDirection`, `InpAllSignalsMatchEntryCriteria`, `InpRequireBBBandTouchForReentry`/`InpRequireQQEScenarioBForReentry`) against a fixed window, and diff the resulting trade list against the same filter enabled on the reference. Isolating one at a time avoids the combinatorial-interaction ambiguity that made the original benchmark forensics hard.

### D8. **Priority 3 — Session/EOD/EOW actions**
**What to compare:** for each `ENUM_EOX_ACTION` value, which sequences close (and at what price) at the exact trigger moment.
**How:** a short window engineered (or selected from history) to have both a profitable and a losing sequence open exactly at the EOD/EOW trigger time; compare per-action.

### D9. **Priority 3 — QQE-only and Both indicator modes**
**What to compare:** entry timing and the AND-gate behavior in Both mode (does a BB breach alone ever trigger without the QQE zone also breached, or vice versa).
**How:** run `INDICATOR_QQE_ONLY` and `INDICATOR_BOTH` over the same window already used for the BB-only benchmark comparison; the existing forensic-comparison methodology (deal-log diffing, balance-curve comparison) applies directly.

### D10. **Priority 3 — Fixed Target and Pure Trailing**
**What to compare:** exact close price/time for each of Fixed Target's three sub-modes and Pure Trailing's pips-vs-dollar-start race and step-block behavior.
**How:** same diagnostic-dump-and-compare method as D1/D4, applied to one representative sequence per mode.

### D11. **Priority 4 — Edge cases requiring induced failure, not just a different setting**
A2/A4/B6 can't be validated against the reference at all (they're about *this* EA's own failure handling, not a behavioral spec to match) — instead, validate by code review of the fix once implemented, plus a forced-failure test (e.g., disconnect during a close, or select a ticket that's already gone) to confirm the fix's recovery path actually works, independent of the reference EA entirely.

---

## Summary

- **5 definite defects (A1–A5)**, two of them (A1, A3) high-severity and directly actionable without needing the reference EA at all — A1 is a pure dead-input bug, A3 is confirmed-by-reading-the-code-and-the-project's-own-history inconsistency with an already-proven fix.
- **6 potential risks (B1–B6)**, mostly "explicitly flagged as an assumption in the code's own comments" — these are honest about their own uncertainty already; this audit just collects them in one place.
- **~25 untested surface-area items (C1–C5)**, the large majority of the EA's total configuration space, none of it exercised in any backtest to date.
- **11-item prioritized test plan (D1–D11)** turning the above into concrete, executable validation steps, ordered by how much a divergence would change trading results.

No code was modified in the course of this audit.
