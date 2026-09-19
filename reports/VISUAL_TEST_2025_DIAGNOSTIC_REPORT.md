# Visual_test_2025.xlsx — Entry/Add-on Discrepancy Root-Cause Report

**Scope:** the 5 "unexpected trade" / "missed entry" discrepancies (cases 1, 2, 6, 8, 9) from
the original 10-item list, per the user's follow-up request to focus on these first.

**Method:** a diagnostic-only build, `DCA_EA_Forensic.mq5`, was created as an exact copy of
`DCA_EA.mq5` with one addition — `ProcessNewBar()` writes one CSV row per closed H4 bar,
recording the full BB/QQE/QMP snapshot, every zone-arm/centre-cross latch, live spread, and
every individual `NewSequenceGatesPass()` gate's pass/fail state for **both** directions, not
just whichever direction the bar's own dot happened to be. Every added line is a pure read
(`SessionProfitLimitReached()`, `ZoneArmedForEntry()`, `CentreCrossReady()`, `SpreadOk()`, etc.
all already exist in the live file and mutate nothing) — verified by a full line-by-line diff
against `DCA_EA.mq5` before trusting any of its output.

**Critical calibration step:** the first headless run used `Model=1` ("Every tick," locally
generated) and produced a materially different trade history than `Visual_test_2025.xlsx` from
2025-02-03 onward — a real add-on that doesn't exist in the historical report. This was *not* a
bug in the forensic build (confirmed by diff), but a genuine tick-model sensitivity: touch-mode
exits read live bid/ask every tick, and `Model=1`'s synthetic intrabar tick path differs from
real historical ticks, so exit timing/price — and everything downstream of it — diverges.
Switching to **`Model=4`** ("Every tick based on real ticks") reproduced `Visual_test_2025.xlsx`
**exactly**, matching deal timestamps down to the second (e.g. `2025.01.28 14:04:11`,
`2025.02.06 08:00:04`) across all 113 deals. All findings below use the `Model=4` run.

This tick-model sensitivity is itself a notable finding — see Common Root Cause C3.

---

## A. Executive Summary

- **5 discrepancies analysed** (cases 1, 2, 6, 8, 9).
- **Entry-condition defects found: 0.** Every one of the 5 trades that appeared "unexpected" or
  "missing" on the visual chart turns out to be either a fully valid, spec-compliant entry the
  user's visual read didn't catch, or a fully valid non-entry correctly blocked by a working
  safety gate.
- **Order-execution (spread gate) explanations: 2** (cases 1, 9) — both confirmed by direct
  spread measurement at the exact tick in question.
- **Signal-persistence (stale pending-signal retry) explanations: 2** (cases 6, 8 partially) —
  the entry's triggering QMP dot is real but occurred on an earlier day than the trade itself,
  because the EA correctly keeps retrying an unconsumed pending signal until its zone re-arms.
- **Exit-timing defects found: 1, but already known** — every one of the resulting trades in
  cases 2, 6, and 8 closed early via the touch-mode live-tick breakeven check (the same root
  cause already documented in `DCA_EA_ENTRY_EXIT_DIVERGENCE_REPORT.md` finding #2), now
  reproduced on 3 further independent dates. This is real but was not part of what the 5 cases
  were nominally asking about (entries), and is not re-litigated in depth here.
- **Common root causes identified: 3** (see section C) — spread protection, pending-signal
  persistence, and tick-model sensitivity. None of the 5 cases traces to a genuine
  entry-detection or BB/QMP-signal-reading bug.

---

## B. Individual Case Analysis

### Case 1 — "Missed BUY entry" 03.02.2025

- **Date/direction:** BUY, window 2025-01-31 → 2025-02-06.
- **Observed (per user):** a BB lower-band cross and blue QMP dot appeared around 03.02.2025
  with no resulting entry.
- **Ground truth:** the EA already had an open BUY sequence (opened 2025-01-31 20:00 @1.04202,
  single leg). A genuine BUY QMP dot fired on the bar closing 2025-02-03 20:00 (order fills
  ~2025-02-04 00:00). The BB buy zone was already armed (since 2025-01-31 08:00) and stayed
  armed. **No trade resulted from this dot at all** — not a new sequence, not an add-on.
- **Relevant EA logic:** `AddOnToAllOpenSequences()` (add-on path, since a sequence was already
  open) and `TryOpenNewSequence()` (new-sequence path, since a pending signal existed) are both
  gated by `SpreadOk()` at the function level, checked before any per-sequence logic.
- **Code path:** `DCA_EA.mq5` — `ProcessNewBar()` → `AddOnToAllOpenSequences(true)` /
  `TryOpenNewSequence(true)` → `SpreadOk()` (`SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) <=
  InpMaxSpread`, default 40 points).
- **Root cause — CONFIRMED:** live spread at that exact tick was **86 points** (vs. the 40-point
  cap), measured directly via the forensic build's added spread logging. This is a textbook
  Friday-close-to-Monday-open weekend gap: EURUSD gapped roughly 170 pips down over the weekend
  (bar low fell from ~1.038 pre-weekend to ~1.021 on Monday's open), and spreads widen sharply
  around a gap reopen before liquidity normalizes. `SpreadOk()` correctly rejected the trade.
- **Secondary factor:** even without the spread block, a brand-new sequence specifically
  (as opposed to an add-on) would *also* have been blocked — `CentreCrossReady(true)` was
  `false` at this point (price hadn't completed a fresh cross back through the centre band
  since the last one), so only the add-on path was ever a live candidate here, and that's the
  one the spread gate blocked.
- **Classification:** Order execution logic (primary) — correct, by-design behavior, not a
  defect. Entry-condition logic (secondary, centre-cross-ready) — also correct.
- **Confidence:** HIGH (directly measured spread value at the decision tick).
- **Recommended correction:** none — this is the spread-protection gate working as intended.
  If desired, the on-chart Sequence Start/End or a new "blocked by spread" diagnostic marker
  could make this visible without a forensic build next time (see Recommended Fix Plan).

### Case 2 — "Unexpected trade" 10.04.2025

- **Date/direction:** BUY, window 2025-04-07 → 2025-04-11.
- **Observed (per user):** a trade opened 10.04.2025 with no entry condition visibly satisfied.
- **Ground truth:** a genuine BUY QMP dot fired on the bar closing 2025-04-10 12:00 (fills
  ~16:00 @1.10978). The BB buy zone had been armed continuously since 2025-04-07, and
  `CentreCrossReady(true)` was already `true`. This is a fully valid, spec-compliant new-sequence
  entry — every gate genuinely passes.
- **Why it looked "unexpected":** most likely the QMP dot itself (a single marker on one H4 bar)
  was missed on visual inspection, and/or the zone having been armed for 3 days prior (since
  Apr 7) wasn't obvious from the chart, since the arming bar and the triggering-dot bar are far
  apart in time.
- **The actual defect in this case is on the exit side, not the entry:** the position closed
  at **2025-04-10 16:00:00**, the *same instant* it opened, at the identical price (1.10978 in,
  1.10978 out) — zero price movement, zero profit.
- **Code path:** `HandleBBCentreOrQQE50()` → `touchBreached` latch (`UpdateTouchBreach()`) +
  `GetSequenceProfitPips()` (live bid/ask, checked every tick via `CheckExitsPerTick()`).
- **Root cause:** this is the already-documented "same-bar entry/exit race" — `CheckExitsPerTick()`
  runs before `ProcessNewBar()` refreshes the snapshot, so a sequence opened on this bar-close
  becomes exit-eligible on the very next tick using the same closed-bar data that just justified
  its entry. See `DCA_EA_ENTRY_EXIT_DIVERGENCE_REPORT.md` finding #2 for the original diagnosis
  — this is a fresh, independent reproduction on a different date, not a new defect.
- **Classification:** Entry — no defect (valid signal). Exit — sequence/state-management +
  tick-timing defect, CONFIRMED, already known.
- **Confidence:** HIGH.
- **Recommended correction:** already proposed and previously reverted pending further testing
  (route the touch-mode breakeven check through `GetSequenceProfitPipsFromClose()`); not
  re-recommended again here without new instruction, since that decision was explicitly left
  open in the earlier investigation.

### Case 6 — "Unexpected trade" 04.08.2025

- **Date/direction:** BUY, window 2025-08-01 → 2025-08-05.
- **Observed (per user):** no valid entry trigger visible for the 04.08.2025 trade.
- **Ground truth:** the triggering QMP dot actually fired 3 days earlier, on the bar closing
  2025-08-01 12:00 — at that time an existing 2-leg buy sequence was open and the dot correctly
  added a 3rd leg via `AddOnToAllOpenSequences()` (matches deal `2025-08-01 16:00 buy 0.02`).
  That same dot also set `g_pendingSignal=true/isBuy=true` for a possible *new* sequence, but
  `CentreCrossReady(true)` was `false` at the time, so it couldn't open one — the pending signal
  was carried forward, unconsumed, exactly per the "retry every bar, no time limit" design.
  The 3-leg sequence then closed (2025-08-04 00:05, +$2.35/+$9.02). On the very next bar close
  (2025-08-04 00:00, i.e. right after that close), `CentreCrossReady(true)` finally flipped
  `true`; the *stale* pending BUY signal from 3 days earlier was retried and succeeded —
  producing the 2025-08-04 04:00 entry (matches deal `buy 0.01 @1.1558`). **No fresh dot exists
  on 04.08.2025 itself** — the bar that opens the trade shows `dot=0`.
- **Code path:** `ProcessNewBar()`'s bottom line — `if(g_pendingSignal &&
  TryOpenNewSequence(g_pendingSignalIsBuy)) g_pendingSignal = false;` — runs every bar
  regardless of whether that bar has its own dot.
- **Root cause:** the pending-signal persistence mechanism, which is documented, intended
  behavior (the guide's own "no time limit" framing for zone-arm retries), not a defect. The
  entry is correctly attributed to Aug 1's dot, not a phantom Aug 4 signal.
- **Secondary, already-known exit finding:** this sequence also closed early relative to its own
  bar (2025-08-04 04:46:43, 46 minutes after opening, tiny +$1.02) — same touch-mode live-tick
  pattern as Case 2, a third independent reproduction.
- **Classification:** Entry — no defect (valid, if visually non-obvious, signal persistence).
  Exit — same known touch-mode timing pattern.
- **Confidence:** HIGH.
- **Recommended correction:** none for the entry. See Case 2 for the exit-side item.

### Case 8 — "Unexpected trade" 24.09.2025

- **Date/direction:** SELL, window 2025-09-22 → 2025-09-24.
- **Observed (per user):** no valid entry trigger visible for the 24.09.2025 trade.
- **Ground truth:** a genuine SELL QMP dot fired on the bar closing 2025-09-24 08:00 (fills
  ~12:00 @1.17726). The SELL zone had armed on 2025-09-23 20:00 (price touched the upper band),
  and `CentreCrossReady(false)` was already `true`. This dot **superseded** an older, unconsumed
  pending BUY signal from 2025-09-22 08:00 (which itself never fired — the buy zone never
  armed during that window) — "a fresh dot always supersedes any older pending one" per the
  code's own documented QMP trend-flip semantics.
- **Code path:** same `NewSequenceGatesPass(false)` chain as Case 2, sell direction.
- **Root cause:** fully valid, spec-compliant entry; not visually obvious because the relevant
  zone-arm event (Sep 23 20:00) and the triggering dot (Sep 24 08:00) are on different bars, and
  a superseded pending signal from 2 days earlier leaves no visual trace.
- **Secondary, already-known exit finding:** closed 2025-09-24 13:13:38, ~73 minutes after
  opening, small +$1.07 — the same touch-mode pattern again, a fourth independent reproduction.
- **Classification:** Entry — no defect. Exit — same known pattern.
- **Confidence:** HIGH.
- **Recommended correction:** none for the entry.

### Case 9 — "Missed add-on" 08.10.2025

- **Date/direction:** BUY, window 2025-10-06 → 2025-10-11.
- **Observed (per user):** an add-on appears to have been missed on 08.10.2025 while a sequence
  was active.
- **Ground truth:** an existing BUY sequence was open (opened 2025-10-07 04:00:02). A genuine
  BUY QMP dot fired on the bar closing 2025-10-08 20:00 — with the buy zone armed and an open
  sequence present, this should have added a leg via `AddOnToAllOpenSequences()`. **It did not.**
  The next BUY dot, on the bar closing 2025-10-10 16:00, *did* successfully add a leg (matches
  deal `2025-10-10 20:00 buy 0.02 @1.16057`).
- **Code path:** identical to Case 1 — `AddOnToAllOpenSequences()` → `SpreadOk()`.
- **Root cause — CONFIRMED:** live spread at the 2025-10-08 20:00 decision tick was **51
  points** (vs. the 40-point cap), directly measured via the forensic build. For comparison,
  the successful add-on two days later (2025-10-10 16:00) had spread = 0 points at that tick.
  20:00 GMT sits near the US-session-close / daily-rollover window, a well-known period of
  temporarily thinner liquidity and wider spreads even without a specific news event or weekend
  gap — the same underlying mechanism as Case 1, just a smaller, more routine trigger.
- **Classification:** Order execution logic — correct, by-design behavior, not a defect. The
  user's date (08.10.2025) is exactly right for *when a qualifying dot occurred*; the add-on
  that eventually appears in the deal log is simply the next opportunity two days later.
- **Confidence:** HIGH (directly measured spread at both the blocked and the successful attempt).
- **Recommended correction:** none — spread gate working as intended.

---

## C. Common Root Causes

### C1 — Spread-gate rejections during genuine liquidity dips (Cases 1, 9)

Both cases trace to the exact same code path (`SpreadOk()`, checked inside both
`AddOnToAllOpenSequences()` and `TryOpenNewSequence()`), both confirmed by direct spread
measurement at the decision tick, both firing during real, explicable liquidity events (a
weekend-gap reopen; a session-rollover thin-liquidity window). This mechanism is invisible on a
standard price/indicator chart — spread isn't plotted — so any spread-gate rejection will read
as "the EA missed a valid signal" to a visual reviewer, when it's actually the EA correctly
protecting against a poor fill. **This fully explains 2 of the 5 cases and is not a defect.**

### C2 — Pending-signal persistence producing entries with no same-day dot (Case 6, partially 8)

The EA's zone-arm/pending-signal design intentionally retries an unconsumed signal on every
subsequent bar close, with no time limit, until its zone re-arms (`CentreCrossReady`). This
means a trade's true trigger can be a QMP dot several days in the past, with nothing visually
present on the actual entry day. This is documented, intended behavior, but it is the single
largest source of "where did this come from" confusion when reading a chart by eye, and
explains the entry side of Case 6 outright and contributes to the framing of Case 8.

### C3 — Tick-model sensitivity of touch-mode exits (methodology finding, not a case defect)

Discovered while calibrating the forensic build: re-running the identical `.set` under
`Model=1` ("Every tick," synthetic) versus `Model=4` ("Every tick based on real ticks")
produced a **materially different trade history** from 2025-02-03 onward, because touch-mode's
live-tick breakeven check is sensitive to the exact intrabar tick path, which the two models
simulate differently. `Model=4` was confirmed to exactly reproduce `Visual_test_2025.xlsx`;
`Model=1` did not. **Any future diagnostic or comparison work on this EA under touch-mode must
use `Model=4`** (or otherwise confirm which model the report being compared against actually
used) — this is a new, general methodological finding, independent of the 5 cases themselves,
and is downstream of the same already-known touch-mode live-tick root cause (see C4).

### C4 — Touch-mode same-bar/early-close pattern (Cases 2, 6, 8's exits — already known, not re-investigated in depth)

Every resulting trade in cases 2, 6, and 8 closed within roughly 0–75 minutes of opening, via
the touch-mode live-tick breakeven check, for a small (often near-zero) profit. This is the
same root cause already documented in `DCA_EA_ENTRY_EXIT_DIVERGENCE_REPORT.md` finding #2 and
independently confirmed again by the ground-up rebuild project (`CORE_DCA_EA_v1`). It is real,
but it is an exit-side finding riding along on top of these 5 nominally entry-side cases, not a
new discrepancy in its own right.

---

## D. Recommended Fix Plan (by root-cause dependency, not by date)

1. **No fix needed for C1 (spread gate) or C2 (pending-signal persistence)** — both are correct,
   working-as-designed behavior. If the *visibility* of these mechanisms is the actual pain
   point (i.e. the goal is to stop misreading correct behavior as a bug during future visual
   reviews), consider a low-cost diagnostic aid: a chart comment or log line noting "entry
   blocked by spread (N pts > cap)" or "opened from a pending signal N bars old" — purely
   observational, no behavior change. Not urgent; only worth doing if this exact confusion
   recurs.
2. **C3 (tick-model sensitivity) is a process fix, not a code fix**: standardize on `Model=4`
   for any future backtest comparison involving touch-mode (`InpBBExitOnBreach=true`), and
   record which model any historical report used, going forward, since the two are not
   interchangeable for this EA's touch-mode path.
3. **C4 (touch-mode early-close) is a pre-existing, already-scoped item** — no new action
   triggered by this investigation; it remains exactly where the earlier investigation left it
   (a proposed fix — routing the breakeven check through the bar-close price variant — was
   implemented, tested, and then reverted pending further decision; that decision is still open
   and unrelated to the 5 cases analysed here).
4. **No new fixes are recommended from cases 1, 2, 6, 8, or 9 specifically** — none of them
   surfaced a genuine entry-detection, BB/QMP signal-reading, or add-on-eligibility defect. This
   is itself a meaningful result: the entry/add-on pipeline held up cleanly under forensic
   scrutiny across 5 independently-flagged "suspicious" dates spanning 8 months of data.

---

## Appendix — Diagnostic artifacts

- `src/experts/DCA_EA_Forensic.mq5` — the instrumented build used for this investigation
  (diagnostic only, not for deployment; recommend deleting once this investigation is closed
  out, per project convention for throwaway diagnostics).
- Forensic CSV logs and raw `.htm`/`.xlsx` reports from both the `Model=1` (miscalibrated) and
  `Model=4` (verified-correct) runs are in the session scratchpad, not committed — regeneratable
  from `DCA_EA_Forensic.mq5` plus `Visual_test_2025_forensic.set` (also scratchpad-only)
  against the same `2025.01.01–2026.01.22` EURUSD H4 range with `Model=4`.
