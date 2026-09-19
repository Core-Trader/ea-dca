# DCA_EA — Entry/Exit Execution Divergence Report

**Source data:** `diagnostics/backtests/DCA_EA_exit_on_breach_true.xlsx`,
`DCA_EA_exit_on_breach_false.xlsx`, `REFERENCE_DCA_V1_Exit_on_breach_true.xlsx`,
`REFERENCE_DCA_V1_Exit_on_breach_false.xlsx` (all EURUSD H4, 2026.01.01–2026.09.14,
100k starting balance). Analysis method: full `Deals` table extraction (openpyxl)
for all four reports, programmatic matching of "new sequence start" events
(first leg of a sequence, volume = 0.01, the base lot under the active
`MULT_LINEAR` multiplier system) by direction and timestamp, and manual
basket-level entry/exit reconciliation for the largest divergences. **No code
was modified for this investigation.**

## Settings caveat (read first)

The two EA reports and the two reference reports were run with **different**
`InpFibSequence`/position-sizing text (though `InpMultiplierSystem=MULT_LINEAR`
makes this irrelevant — both actually scale 1,2,3,4,5... lots) and both pairs
show `InpMaxSequencesPerDirection=3`, `InpFibSequence` cosmetic differences
only. Confirmed: all four reports share identical `InpBBPeriod`, `InpBBDeviation`,
QMP settings, `InpExitStrategy=0` (BB Centre Band), `InpUseDynamicStop=false`,
`InpBreakevenBufferPips=10.0`. This is a fair, apples-to-apples comparison on
the signal/entry/exit logic — the mismatch is cosmetic, not substantive.

## Summary scoreboard

| | EA touch (`=true`) | REF touch (`=true`) | EA bar-close (`=false`) | REF bar-close (`=false`) |
|---|---|---|---|---|
| Total deals | 95 | 95 | 111 | 99 |
| Closing deals (outs) | 47 | 47 | 55 | 49 |
| New-sequence starts | **29** | **21** | **29** | **21** |
| Net profit | $105.95 | $280.96 | $269.59 | $304.99 |
| Profit Factor | 2.77 | 4.55 | 6.15 | 4.79 |

Two things jump out immediately:
1. **New-sequence-start count is identical (29 vs 21) in both touch and
   bar-close modes** — this is an entry-side effect, completely independent
   of the `InpBBExitOnBreach` toggle.
2. **Touch mode's profit gap ($175, PF 2.77 vs 4.55) is far larger than
   bar-close mode's ($35, PF 6.15 vs 4.79)** — there is an *additional*,
   touch-mode-specific loss on top of the shared entry-side effect.

These point to two independent, separately-traceable root causes.

---

## #1 — Entry side: 8 net extra "new sequence" opens (HIGH confidence, HIGH impact)

### Evidence

Matching all 29 (EA) vs 21 (REF) new-sequence-start events by direction within
a 3-day window (identical result in both touch and bar-close configs):

- **19 matches**, and for every one of them the leg-1 entry timestamp and
  price are **exactly identical** between EA and reference (e.g.
  `2026.01.02 04:00:06 buy @1.17609`, `2026.02.03 20:00:00 buy @1.18163`,
  `2026.08.31 20:00:00 buy @1.16167` — all byte-identical). This confirms the
  base QMP-dot detection and first-leg entry logic are correct and not in
  question.
- **10 EA-only** new-sequence opens with no reference counterpart within 3
  days: `01.12 20:00 buy@1.16682`, `02.26 12:00 buy@1.17974`,
  `05.08 20:00 buy@1.17712`, `05.11 08:00 sell@1.17504`,
  `05.27 16:00 buy@1.16439`, `06.11 20:00 sell@1.15089`,
  `07.23 16:00 sell@1.13849`, `08.13 00:05 sell@1.15234`,
  `08.19 12:00 buy@1.15982`, `08.26 12:00 sell@1.16708`.
- **2 REF-only** new-sequence opens with no EA counterpart: `01.16 16:00
  buy@1.16191`, `06.09 08:00 buy@1.15456`.

### Worked example (2026-01-12 vs 01-16)

| | EA | Reference |
|---|---|---|
| Seq1 leg3 | 01.12 04:00 buy 0.03 @1.16562 | 01.12 04:00 buy 0.03 @1.16562 *(identical)* |
| Seq1 leg4 | 01.16 16:00:01 buy 0.04 @1.16191 | 01.16 16:00:01 buy 0.04 @1.16191 *(identical)* |
| **New Seq2 leg1** | **01.12 20:00:01 buy 0.01 @1.16682** | **01.16 16:00:01 buy 0.01 @1.16191** |

The reference only opens its second, parallel buy sequence on the *same bar*
that seq1 gets its 4th DCA leg (01.16). The EA opens an equivalent second
sequence **4 days earlier**, on 01.12, at a worse price. Everything else about
seq1 (all 4 legs) matches exactly, so this isn't an indicator-value or
bar-processing bug — it's specifically the *second-sequence-arming* gate
firing too early.

### Code trace

New-sequence opens are gated by `NewSequenceGatesPass()` (`DCA_EA.mq5:1533`),
whose only live gates under these settings (all width/MA/HTF/reentry filters
are off in this test) are `ZoneArmedForEntry()` (`:1065`) and
`CentreCrossReady()` (`:1123`).

`ZoneArmedForEntry()` is armed by `UpdateZoneBreachLatches()` (`:1028`) via
`BBBuyBreach()`/`BBSellBreach()` (`:1017-1018`):

```mql5
bool BBBuyBreach()   { return(g_bbSnapshotValid && g_bar1Low  <= g_bbLower1); }
bool BBSellBreach()  { return(g_bbSnapshotValid && g_bar1High >= g_bbUpper1); }
```

This is the **H1 fix** from `DCA_EA_DOCS_AUDIT_REPORT.md` — changed from
requiring both the touch AND the bar's own close beyond the outer band, to
touch-only. The archived `DCA_EA_V2.mq5` (pre-H1) and `DCA_EA_V3.mq5`
(H1 reverted) snapshots both still require touch-AND-close for this same
latch. A touch-only latch arms on strictly more bars than a touch-and-close
latch, and stays armed until consumed — so it will, on average, let a new
sequence's gates pass *earlier* than the stricter definition would.

The latch is consumed (`ConsumeZoneLatch()`, `:1052`) the moment a new
sequence actually opens, which is consistent with what we see on 01.16: by
then the EA's zone latch (and `g_centreCrossReadyBuy`) had already been
spent on 01.12, so the EA's 01.16 event shows up only as an **add-on** to the
already-open seq2 (`AddOnToAllOpenSequences()`, `:1803`, which does not
require `ZoneArmedForEntry()` under these settings) rather than a fresh
sequence — exactly matching the "EA-only 01.12 / REF-only 01.16" pairing
found by the matcher.

### Confirmed vs. hypothesis

- **Confirmed**: the 10 EA-only / 2 REF-only new-sequence-start pattern, from
  the deal logs directly.
- **Confirmed**: `BBBuyBreach()`/`BBSellBreach()` (the entry-arming latch) use
  the H1 touch-only definition in the live EA, and a stricter touch-and-close
  definition in the archived pre-H1/H1-reverted snapshots.
- **High-confidence hypothesis, not yet re-verified on this exact dataset**:
  that H1 specifically (as opposed to `CentreCrossReady`/§15, which is
  unchanged since the last fix and shared by all snapshots) is the cause.
  This is strongly supported by a prior investigation this session (documented
  in `DCA_EA_DOCS_AUDIT_REPORT.md`'s C1/H1 A/B testing): isolating H1 alone
  raised new-sequence starts from a 22-start pre-fix baseline to 29 with H1
  applied, against a reference baseline of 21 — the same ~+7/+8 delta seen
  here. It has not, however, been re-confirmed with a fresh `DCA_EA_V3.mq5`
  (H1-reverted) backtest run against *this* dataset's exact settings.

### Impact

Directly explains the new-sequence-start gap (29 vs 21, both modes) and, by
extension, most of the basket-fragmentation pattern previously documented
(more, smaller sequences than the reference's equivalent larger baskets).
Independent of `InpBBExitOnBreach` — affects both configurations equally.

---

## #2 — Exit side: touch-mode breakeven check is live-tick, not bar-close (HIGH confidence, HIGH impact within touch mode)

### Evidence — same basket, closed at two different prices

Seq1 from the 2026.01.02 buy sequence (4 legs, entries **byte-identical**
between EA and reference: 1.17609 / 1.17145 / 1.16562 / 1.16191, all on
matching dates) closes as follows in touch mode:

| | Close time | Close price | Basket profit |
|---|---|---|---|
| EA | **2026.01.20 09:22:15** | **1.16735** | **$10.01** |
| Reference | **2026.01.20 12:00:00** | **1.17264** | **$62.91** |

A **$52.90 difference on this single basket** — roughly 30% of the entire
$175 touch-mode profit gap between the two engines. The EA's close timestamp
(09:22:15) is not an H4 bar boundary (H4 bars close at 00/04/08/12/16/20);
the reference's close timestamp (12:00:00) is exactly one. The reference
waited for the next real candle close, captured a 53-pip better exit price,
and the EA closed intrabar, early, and worse.

This is not universal — several other matched baskets (e.g. the 02.03/02.06
buy sequence, both closing 02.09 08:00:00 at 1.18329 vs 1.18332; the
03.04/03.09 buy sequence, both closing 03.10 04:00:00 at 1.16255 vs 1.16258)
close at **identical, bar-aligned timestamps** in both engines. So the
divergence is intermittent — it only shows up when the live price happens to
cross the breakeven threshold measurably before the bar it's in actually
closes.

### Code trace

`InpBBExitOnBreach=true` routes `HandleBBCentreOrQQE50()` (`:2359`) through
the `touchBreached` sticky latch (`UpdateTouchBreach()`, `:2034`, which is
bar-close-updated only — called from `ProcessNewBar()`). But the downstream
profit gate uses:

```mql5
double requiredPips = recoveryActive ? InpBreakevenBufferPips : 0.0;
bool atBreakeven = useTouch ? GetSequenceProfitPips(isBuy, idx) >= requiredPips
                             : GetSequenceProfitPipsFromClose(isBuy, idx) >= requiredPips;
```
(`:2380-2382`)

`GetSequenceProfitPips()` (`:1952`) computes profit from **live**
`SymbolInfoDouble(_Symbol, SYMBOL_BID/ASK)` — not the last closed bar's close.
And `HandleBBCentreOrQQE50()` is reached via `CheckExitsPerTick()`, called
from `OnTick()` (`:3078`) on **every tick**, not gated to `IsNewBar()`.

So once `touchBreached` latches true (at some bar close), the sequence closes
on the very first subsequent **tick** where live price crosses the
breakeven/buffer threshold — not on the close of a candle at all. This
directly contradicts the EA User Guide's own wording (quoted in the code's
own header comment at `:2017-2021`): *"...the sequence will close on the
close of that candle. It does not matter where the actual candle closes in
relation to the BB centre band."* The guide describes a bar-close-timed
close; the implementation is tick-reactive once armed.

### Confirmed vs. hypothesis

- **Confirmed**: `GetSequenceProfitPips()` reads live bid/ask, is called via
  `CheckExitsPerTick()` on every tick, and its sibling
  `GetSequenceProfitPipsFromClose()` (bar-close variant) exists and is used
  by the `=false` (bar-close) path but NOT by the touch path — this is a
  direct code read, not an inference.
  This is also confirmed empirically by the 01.20 09:22:15 vs 12:00:00
  example above (a non-bar-aligned close timestamp is only possible from a
  tick-driven check).
- **Confirmed**: the guide's own quoted text (already in the code's comments)
  describes a bar-close-timed mechanism, so this is a genuine spec/code
  mismatch, not a matter of interpretation.
- **Hypothesis, not yet quantified**: that this single mechanism accounts for
  most/all of the *incremental* touch-mode gap (i.e., the $140 difference
  between touch mode's $175 gap and bar-close mode's $35 gap). The one worked
  example accounts for $52.90 of it; the remainder would need the same
  basket-by-basket reconciliation applied across all 19 matched sequences to
  confirm quantitatively.

### Impact

Directly explains why touch mode's profit/PF gap (PF 2.77 vs 4.55) is much
larger than bar-close mode's (PF 6.15 vs 4.79), despite both modes sharing
the identical entry-side fragmentation issue (#1). This is the dominant
touch-mode-specific factor.

---

## Discrepancies checked and ruled out / not implicated

- **Leg-1 entry price/timing for matched sequences**: exact match in all 19
  cases — rules out indicator-value drift (BB middle/QMP dot timing) as a
  general-purpose explanation; the two root causes above are narrowly scoped
  gate/timing issues, not a systemic signal-calculation divergence.
- **Position sizing**: `MULT_LINEAR` is active in all four reports regardless
  of the cosmetic `InpFibSequence` text differences — volumes step
  0.01/0.02/0.03/0.04... identically in EA and reference for every matched
  sequence, confirmed directly from the deal volumes.
- **Commission/spread/slippage assumptions**: not separately audited in this
  pass (both reports are `FTMO-Server4` symbol data, same period) — flagged
  as untested, not as a finding.

## Recommended next diagnostic steps (no code changes)

1. **Isolate H1 cleanly on this exact dataset.** Run `DCA_EA_V3.mq5`
   (H1-reverted, C1-kept — already compiled clean) through the Strategy
   Tester with the *same* settings as `DCA_EA_exit_on_breach_true.xlsx` /
   `_false.xlsx`, and re-run the new-sequence-start matcher. If the 10/2
   split collapses to ~0, H1 is fully confirmed as root cause #1; if it
   doesn't, `CentreCrossReady`/§15 needs a second look.
2. **Quantify root cause #2 across all 19 matched baskets**, not just the one
   worked example — pull each matched sequence's full close-leg set from both
   `ea_true.csv` and `ref_true.csv`, sum profit per basket, and total the
   EA-vs-REF delta to see what fraction of the $175 touch-mode gap is
   attributable to intrabar-vs-bar-close closing versus other effects (e.g.
   basket composition differences carried over from root cause #1).
3. Once both are quantified, decide fixes in priority order: root cause #1
   (H1) has a ready-made rollback (`DCA_EA_V3.mq5`'s reverted
   `BBBuyBreach()`/`BBSellBreach()`); root cause #2 would need
   `HandleBBCentreOrQQE50()`'s touch-mode `atBreakeven` check changed to use
   `GetSequenceProfitPipsFromClose()` instead of the live
   `GetSequenceProfitPips()` — bringing it in line with both the guide's
   wording and the `=false` path's existing pattern. Neither change has been
   made; this report is diagnosis only, per the request.
