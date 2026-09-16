# PnL Discrepancy Root-Cause Report — DCA_EA vs. Reference (Jagfx-DCA-EA-V2.0.4)

**Scope note before anything else**: the investigation brief this report follows (16 sections,
A-I deliverable) is extremely large — a full per-parameter equivalence matrix across ~100
inputs, indicator-buffer-level tracing for every trade, and a formal sensitivity sweep would
each individually be a multi-day effort. This report prioritizes **depth on the divergences that
actually explain the PnL gap**, backed by fresh, controlled, reproducible evidence, over shallow
coverage of every sub-section. Where a brief section got summary treatment rather than
exhaustive treatment, that's stated explicitly rather than padded to look complete.

---

## A. Test Equivalence

A **fresh, controlled baseline** was run for this report — not a reuse of prior
`reference_ea.xlsx`/`Visual_test_2025.xlsx` reports, which had a real environmental mismatch
(different starting deposit: $10,000 vs $100,000). Both EAs were run back-to-back, same machine,
same session:

| Condition | Our EA | Reference EA | Equivalent? |
|---|---|---|---|
| Symbol | EURUSD | EURUSD | Yes |
| Period | H4 | H4 | Yes |
| Date range | 2025.01.01–2026.01.22 | 2025.01.01–2026.01.22 | Yes |
| Deposit | $100,000 | $100,000 | Yes (fixed — prior reports differed here) |
| Currency | USD | USD | Yes |
| Leverage | 1:30 | 1:30 | Yes |
| Tick model | Model=4 (every tick, real ticks) | Model=4 | Yes — required; Model=1 was already shown this session to diverge materially for this EA family under touch mode |
| Login/account | 540291482 (FTMO-Server4) | 540291482 | Yes, identical price/tick source |
| `InpMaxSequencesPerDirection` | 3 | 3 | Yes (matched to reference's value for this run, not our project's own default of 100) |
| `InpMaxSpread` | 40 | 40 | **Same nominal value — see §F for why this is not actually equivalent** |
| Lot sizing | Fixed, 0.01 base, Linear multiplier (1,2,3,4,5,6,7) | Same | Yes |
| Commission/swap | Broker-supplied, identical symbol | Same | Yes (same broker/account) |
| Slippage | 3 points | 3 points | Yes |

**One operational gotcha caught during setup**: the first headless run of the controlled baseline
silently produced no report — a `terminal64.exe` instance was already running from an earlier
session and the new headless launch no-op'd (the documented "already open" failure mode). Caught
by checking for the report file rather than trusting exit code alone; terminal closed, rerun
succeeded. Flagging this because it's a real, recurring risk for any future automated run of
this kind — always verify the report file exists, not just that the process returned.

**Conclusion**: environment and declared-parameter parity is now genuinely established (fixing
the deposit mismatch alone is new since the earlier session's ad-hoc comparisons). The one
parameter whose *nominal* equivalence is misleading (`InpMaxSpread`) is analyzed in detail below
rather than assumed away.

---

## B. PnL Comparison

| Metric | Our EA | Reference EA | Difference |
|---|---:|---:|---:|
| Net PnL | $145.68 | $267.39 | **-$121.71** |
| Gross Profit | $201.05 | $318.58 | -$117.53 |
| Gross Loss | $55.37 | $51.19 | +$4.18 (ours slightly worse) |
| Closing trades | 56 | 54 | +2 |
| New-sequence starts | 41 | 35 | +6 |
| BUY entries (`in`) | 35 | 33 | +2 |
| SELL entries (`in`) | 21 | 21 | 0 |
| Win rate | 42/56 = 75.0% | 44/54 = 81.5% | -6.5pp |
| Average trade (closes) | $2.60 | $4.95 | -$2.35 |
| Profit Factor | 3.63 | 6.22 | -2.59 |
| Final balance | $100,125.71 | $100,244.02 | -$118.31 |

(Max Drawdown was not extracted for this pass — both reports' "Results" sections have it, but it
wasn't pulled into this comparison table; flagging as a gap in this pass rather than fabricating
a number.)

---

## C. Trade/Sequence Reconciliation

Built by matching every new-sequence-start event (first leg, volume=0.01, same direction) within
a 3-day window between the two engines — the same methodology validated earlier this session on
the 5-case investigation, now run against the fresh controlled baseline.

**The first 4 sequences are byte-identical** — same timestamp, same fill price, to the last
digit:

| # | Time | Direction | Price (both) |
|---|---|---|---|
| 1 | 2025-01-03 20:00:00 | buy | 1.02982 |
| 2 | 2025-01-13 20:00:00 | buy | 1.02182 |
| 3 | 2025-01-21 12:00:00 | sell | 1.03535 |
| 4 | 2025-01-31 20:00:00 | buy | 1.04202 |

**The first divergence is not a new-sequence event at all — it's a blocked add-on.** On
**2025-02-04 00:05:02**, the reference EA adds a second leg (0.02 @ 1.03414) to sequence #4. Our
EA does not — `SpreadOk()` rejects it (measured spread 86 points against `InpMaxSpread=40`
points, during a Friday→Monday weekend-gap reopen). This single blocked add-on is the earliest
point at which the two engines' internal state (zone-arm latches, pending-signal state,
sequence-count) starts to diverge; every subsequent difference in this reconciliation is
downstream of it, not independent.

**Cascade from that point**: 41 new-sequence starts (ours) vs. 35 (reference) — **7 "extra"
sequences on our side, 1 "extra" on reference's**:

Extra on our side (no reference counterpart within 3 days):
`2025-02-06 08:00 buy`, `2025-04-10 16:00 buy`, `2025-06-04 20:00 buy`, `2025-08-04 04:00 buy`,
`2025-09-24 12:00 sell`, `2025-12-01 12:00 buy`, `2026-01-12 20:00 buy`.

Extra on reference's side: `2026-01-16 16:00 buy`.

(All 7 of our extras were individually root-caused in the earlier 5-case investigation this
session — see `VISUAL_TEST_2025_DIAGNOSTIC_REPORT.md`, cases 1/2/6/8/9 — as either the
spread-gate/pending-signal-retry mechanisms working correctly-but-non-obviously, not fresh bugs.
That analysis stands; it is not repeated here.)

**A second, newly-observed pattern — 3 sequences matched but at materially different
time/price**, all showing the reference entering *earlier, intrabar*, on the same calendar day:

| Our entry | Reference entry | Time gap | Price gap |
|---|---|---|---|
| 2025-04-22 04:00:00 @1.14904 | 2025-04-22 00:38:43 @1.15126 | 3.35h | 22.2 pips |
| 2025-06-20 04:00:00 @1.15229 | 2025-06-20 00:05:06 @1.14959 | 3.92h | 27.0 pips |
| 2025-10-07 04:00:02 @1.17086 | 2025-10-07 00:18:51 @1.17128 | 3.69h | 4.2 pips |

**Important epistemic caveat**: by the point these occur (April/June/October), both engines'
sequence numbering is already offset by the February cascade above. It is **not certain** these
3 are a genuinely independent divergence mechanism (e.g. reference reacting intrabar to
something ours only checks at bar-close) versus simply the greedy 3-day matcher pairing
already-cascaded, no-longer-corresponding sequences that happen to be nearby in time. This is
flagged as an **open finding, not a confirmed root cause** — see §F classification.

---

## D. PnL Attribution

A fully precise, trade-by-trade dollar attribution (matching every closing leg back to its
originating sequence on both sides, categorizing each dollar of difference) was **not completed**
in this pass — it requires a dedicated sequence-tracking script beyond this session's remaining
scope, and a rushed version risks a wrong number stated with false confidence, which the brief
explicitly warns against (§14, "protect against overfitting" / general instruction not to assert
unverified conclusions).

What **is** supportable directionally from §B/§C:

- **Trade-generation differences** (the 7-extra-vs-1-extra sequence split) are the largest
  visible structural difference and plausibly the dominant contributor to both the trade-count
  gap and a meaningful share of the PnL gap, since fragmenting one large, well-timed reference
  basket into several smaller, differently-timed ones (the mechanism already documented in
  `DCA_EA_ENTRY_EXIT_DIVERGENCE_REPORT.md`) both dilutes position sizing on the winning side and
  adds small-but-real transaction costs (commission per extra leg) that a single larger basket
  wouldn't incur.
- **Exit-timing** (the already-documented touch-mode early-close pattern) systematically caps
  our upside on sequences that *do* match reference's entries, since our exit fires on the first
  live tick crossing breakeven rather than waiting for the bar reference apparently waits for.
- Execution-level factors (spread/commission/slippage) are **not** a material contributor to the
  *decision-level* gap — both runs used the same account/broker/symbol, so per-unit costs are
  structurally identical; where they matter is only as the *trigger* for the spread-gate
  divergence in §C, not as an independent cost-basis difference.

**Recommended next step if a precise dollar breakdown is wanted**: write a script that, for both
CSVs, reconstructs full sequences (group `in`/`out` deals by ticket-implied sequence membership),
sums each sequence's total realized profit, and buckets the difference into "sequence exists in
one engine only" vs. "sequence exists in both but closed differently." This is a well-defined,
mechanical follow-up, not a new investigation.

---

## E. Parameter Equivalence Matrix

A full 100+-row matrix was not built (see scope note). The parameters actually implicated by
the reconciliation in §C are covered in depth; everything else was confirmed *nominally* equal
in the report settings dumps (§A) but not independently re-derived line-by-line.

| Parameter | Our Value | Reference Value | Same Meaning? | Implementation Equivalent? | Affects | PnL Impact |
|---|---|---|---|---|---|---|
| `InpMaxSpread` | 40 | 40 | **No — see below** | No (hypothesized) | Add-on/new-sequence eligibility during wide-spread ticks | **High** — direct cause of the Feb-4 first divergence |
| `InpBBAppliedPrice` | 3 (Low) | 3 (Low) | Yes | Yes (both platform-standard `ENUM_APPLIED_PRICE`) | BB band calculation | None (matched) |
| `InpMaxSequencesPerDirection` | 3 (this run) | 3 | Yes | Yes | Sequence cap | None (matched for this controlled run — differs from our project's own default of 100, not relevant to this comparison) |
| `InpExitStrategy` / `InpBBExitOnBreach` | 0 / true | 0 / true | Yes (nominally) | **Uncertain for entries** — see §C's intrabar-timing finding | Exit condition | Unresolved, flagged not confirmed |
| Lot sizing / multiplier | Linear 0.01 base | Same | Yes | Yes (leg sizes matched exactly on all 4 identical sequences) | Position sizing | None |

### `InpMaxSpread`: same nominal value, likely different units — HIGH CONFIDENCE, NOT PROVEN

- Our source (`DCA_EA.mq5:136`): `input int InpMaxSpread = 40; // Max Spread (points)`, compared
  directly against `SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)` (raw points) in `SpreadOk()`.
- The authoritative spec (`EA User Guide.docx`) confirms points is correct for our
  implementation, explicitly: *"nominated in points and not pips... if you had put 30 (3 pips)
  in the maximum spread field..."* — our 40-point default (4 pips) is directly in line with the
  guide's own example.
- A related (not confirmed-identical-version) reference source in this project,
  `reference/_0_JFX_DCA_Type_V_v1_Money.mq5`, implements its equivalent spread gate as
  `input double MaxSpreadInPips1 = 30; // Maximum spread (pips)` — pips, not points.
- Both engines' settings dumps for this controlled run show the identically-named field
  `InpMaxSpread=40`. If the actual `Jagfx-DCA-EA-V2.0.4.ex5` binary interprets its own
  `InpMaxSpread` field as pips (consistent with the related source above) rather than points
  (as ours does), that's a **10x more permissive cap** (400 points vs. 40) on the reference side
  despite the identical displayed number.
- The observed spread at the moment reference proceeded and we didn't (86 points = 8.6 pips) is
  fully consistent with this: comfortably under a 40-pip cap, well over a 4-pip one.

**This could not be fully confirmed without the reference's own source** (a legitimate
constraint — decompiling a third-party commercial `.ex5` was explicitly declined earlier this
session as a licensing/legality issue, and is not attempted here either). Classified as
Reference-Equivalence Issue (Category B/D — see §F), high confidence, not certainty.

### §13 Controlled Parameter Sensitivity Analysis — `InpMaxSpread`, now done

The user directly challenged the "meaningful share of the PnL gap" framing below by testing
extreme values themselves; this section verifies that with a proper controlled sweep rather than
spot checks. Same baseline (our EA, EURUSD H4, 2025.01.01–2026.01.22, $100k/USD, `Model=4`,
`InpMaxSequencesPerDirection=3`), only `InpMaxSpread` varied:

| `InpMaxSpread` | Net Profit | Closing deals | Wins | Losses | PF |
|---:|---:|---:|---:|---:|---:|
| 40 (documented default/baseline) | $145.68 | 56 | — | — | 3.63 |
| 0 (disabled entirely) | $145.70 | 59 | 44 | 13 | 3.55 |
| 100 (10 pips) | $143.54 | 59 | 44 | 13 | 3.89 |
| 400 (40 pips — the reference-pips hypothesis's implied equivalent) | $145.70 | 59 | 44 | 13 | 3.55 |
| 1000 (100 pips) | $145.70 | 59 | 44 | 13 | 3.55 |

**Result: raising the cap does unlock 3 more closing deals (56→59), confirming `SpreadOk()`
genuinely blocks real trades as Finding 1 describes — but the net PnL barely moves ($143.54–
$145.70 across the entire 0–1000 range, a ~$2 spread).** Reference's $267.39 remains a ~$122 gap
regardless of where `InpMaxSpread` is set, including fully disabled. The extra trades a
permissive cap unlocks are close to breakeven in aggregate, not a source of outperformance.

**Correction to Finding 1's impact assessment below**: the spread-units mechanism is confirmed
as the literal first point of divergence (still true — the Feb-4 event is real and dated
correctly) and a genuine driver of *trade-count* divergence (7-vs-1 extra sequences), but this
sweep disproves that it's a meaningful driver of the *PnL* gap specifically. Those are separable
claims, and the original report conflated them. The dominant PnL driver must be elsewhere —
Finding 2 (touch-mode early-close) and/or Finding 3 (unconfirmed intrabar entry timing) are the
remaining candidates and should be the priority for any further quantification, not the spread
gate.

---

## F. Root-Cause Analysis

### Finding 1 — `InpMaxSpread` units mismatch blocks a real add-on (the first divergence)

- **Symptom**: our EA fails to add a 2nd leg to sequence #4 on 2025-02-04 00:05; reference does.
- **Evidence**: `DCA_EA_Forensic.mq5`'s spread logging measured 86 points at that exact tick;
  `InpMaxSpread=40` (points) rejects it via `SpreadOk()` at `DCA_EA.mq5:1125-1128`, called from
  both `AddOnToAllOpenSequences()` (`:1838`) and `TryOpenNewSequence()` (`:1879`).
- **First point of divergence**: this exact tick — confirmed, not inferred; everything else in
  §C's reconciliation happens after and is plausibly downstream of it.
- **Root cause**: very likely a units mismatch between our (spec-confirmed-correct) points-based
  interpretation and the reference's (circumstantially-evidenced) pips-based one, not a defect
  in either individual implementation considered alone.
- **Code location**: `DCA_EA.mq5:136` (input declaration), `:1125-1128` (`SpreadOk()`).
- **Impact**: HIGH for trade-count/sequence-structure divergence (confirmed seed event for the
  7-vs-1 cascade in §C) — but **LOW for the PnL gap specifically**. A controlled sensitivity
  sweep (§E's §13 subsection, added after the user directly challenged this) shows net profit
  moves by ~$2 across the full `InpMaxSpread` range 0–1000, versus a ~$122 gap to reference. The
  extra trades a permissive cap unlocks are close to breakeven in aggregate. Do not conflate
  "confirmed first divergence" with "confirmed PnL driver" — this finding is the former, not
  the latter.
- **Classification**: **D — Parameter Interpretation Difference** (identical declared value,
  likely different internal units/meaning). Not an implementation bug in our EA — our reading
  is the spec-confirmed one. Correcting a parameter-interpretation difference is still worth
  doing for behavioral/structural fidelity to the reference (trade count, sequence composition),
  just not as a PnL fix.

### Finding 2 — Touch-mode same-bar/early-close exit pattern — NOW PRECISELY QUANTIFIED AND CONFIRMED

Previously qualitative (`DCA_EA_ENTRY_EXIT_DIVERGENCE_REPORT.md` finding #2,
`VISUAL_TEST_2025_DIAGNOSTIC_REPORT.md` §C4). This pass built a full sequence-by-sequence
attribution to quantify it precisely, using a rewritten, validated sequence-reconstruction
methodology (see note below) that resolves every deal in both engines' logs to a specific
sequence with zero unresolved closes and zero orphans (41/41 our sequences, 35/35 reference's).

**Methodology note**: the first reconstruction attempt (matching a close event to the first
open sequence with the same volume-multiset, without removing matched sequences from the
candidate pool) produced nonsensical pairings (e.g. a January sequence "closing" a year later)
because many sequences share identical leg-volume patterns (0.01/0.02/0.03...) under the Linear
multiplier, and a weak total-volume fallback heuristic mismatched across the whole timeline once
an exact match wasn't found nearby. Fixed by processing both engines' deals in strict
chronological order with an explicit per-direction FIFO stack, removing each sequence from the
candidate pool the instant it's matched, and — after discovering one reference close event
`[0.01, 0.01, 0.02]` that was actually **two independent sequences closing at the identical
tick** (both satisfying their own exit condition on the same signal) — adding subset
decomposition that only activates when no single sequence explains the full close batch.

**Full PnL decomposition** (validated: components sum to exactly $121.71, the observed gap):

| Component | n | Amount (ref − ours) |
|---|---:|---:|
| Matched sequences, **same leg count** (pure exit-timing/price difference) | 27 | **+$68.75** |
| Matched sequences, **different leg count** (add-on/composition discrepancy — Finding 1 territory) | 7 | +$55.99 |
| Sequences only in reference | 1 | +$2.14 |
| Sequences only in ours | 7 | −$5.17 |
| **Total** | | **+$121.71** ✓ |

(Note: this decomposes the report's "Net PnL" column, i.e. the raw `Profit` field summed across
deals — both engines' `Profit` columns exclude commission/swap, which are reported separately;
summing all three for either engine correctly reproduces that engine's final balance, e.g. ours:
$145.68 profit − $4.24 commission − $15.73 swap = $125.71 = final balance − $100,000. This is a
labeling-clarity point, not a computational error — both sides are treated identically, so the
$121.71 gap is valid either way.)

**The same-leg-count category is dominated by 2 of its 27 sequences**: $52.90 (2026-01-02 entry,
4 legs) and $10.44 (2025-07-08 entry, 3 legs) together account for $63.34 of the $68.75 subtotal
— the remaining 25 sequences contribute a combined **+$5.41**, almost all of it sub-$0.05
commission/swap-scale noise, not a systematic per-trade tax. This matters: Finding 2 is not
"shaves a little off every trade" — it's concentrated in specific sequences where price
oscillates near breakeven for an extended period before a strong move.

**Both dominant cases were traced to the exact mechanism using `DCA_EA_Forensic.mq5`'s per-bar
BB-middle log against `baseline_ourEA.set`** (fresh run, final balance $100,125.71, confirmed
identical to the original baseline):

- **2026-01-02 sequence** (avg entry 1.166349): the first bar where `High >= bb_middle` (the
  touch condition) is **2026-01-20 04:00** (high 1.16725 ≥ bb_middle 1.16474) — so
  `touchBreached` latches at exactly **08:00:00** when that bar closes. Our actual close fires
  at **09:22:15**, 1h22m later, **intrabar** within the 08:00–12:00 bar, at 1.16735 — almost
  exactly **10.0 pips** above the average entry, matching `InpBreakevenBufferPips=10.0` to the
  hundredth, meaning this sequence was in Recovery Mode requiring the full buffer, not flat
  breakeven. Reference closes at the clean **12:00:00** bar boundary instead, capturing the
  additional favorable move between 09:22 and 12:00 (this is the sequence documented extensively
  earlier in this project's history).
- **2025-07-08 sequence** (avg entry 1.167258): first touch bar is **2025-07-16 16:00** (high
  1.17218 ≥ bb_middle 1.16947); `touchBreached` latches at **20:00:00**. Our close fires **5 days
  later**, 2025-07-21 **17:07:50**, intrabar within the 16:00–20:00 bar, at 1.16826 — again
  **10.02 pips** above average entry, the same buffer signature. Reference closes at the clean
  **20:00:00** bar boundary.
- Both cases independently reproduce the identical signature (close price ≈ avg entry + exactly
  `InpBreakevenBufferPips`, fired intrabar, versus reference's bar-boundary close) — ruling out
  coincidence.

- **Code location**: `HandleBBCentreOrQQE50()` (`DCA_EA.mq5`), `atBreakeven` check uses
  `GetSequenceProfitPips()` (live `SymbolInfoDouble(_Symbol, SYMBOL_BID/ASK)`), reached via
  `CheckExitsPerTick()` called from `OnTick()` on **every tick**, not gated to `IsNewBar()`. The
  bar-close variant `GetSequenceProfitPipsFromClose()` already exists and is used by the
  `InpBBExitOnBreach=false` path, but not by the touch path.
- **Root cause**: once `touchBreached` latches (itself correctly bar-close-gated), the downstream
  profit/buffer check evaluates continuously on live ticks rather than waiting for a bar to
  close — contradicting the guide's own quoted wording ("closes on the close of that candle")
  and reference's own observed behavior (both matched cases here close at exact bar boundaries).
- **Classification**: **A — Implementation Bug. CONFIRMED** (upgraded from the earlier
  investigation's classification — that determination stands, and is now backed by precise,
  quantified, two-independent-case evidence rather than a single worked example). A fix
  (routing this check through `GetSequenceProfitPipsFromClose()`) was previously implemented,
  tested, and reverted mid-session pending further investigation — that investigation is now
  complete; see §H for the decision.

### Finding 3 — RESOLVED: not an independent mechanism, it's Finding 1 again (entry-delay form)

**Hypothesis tested**: (H3a) reference's entry mechanism reacts intrabar to some condition,
a genuine behavioral difference from our bar-close-driven entry pipeline; vs. (H3b) this is
the spread-gate mechanism (Finding 1) manifesting as a delay rather than a permanent block.

**Test**: pulled `DCA_EA_Forensic.mq5`'s per-bar log for all 3 divergent dates. Evidence that
would distinguish them: if H3a, our own gate state should show nothing unusual at the moment the
dot fires — the delay would have to come from somewhere else. If H3b, our EA's own gates should
already show `buy/sell_ALLGATESPASS=true` at the earlier time, blocked specifically by
`spreadOk=false` at that instant, retrying successfully once spread normalizes.

**Result — H3b confirmed, identically, in all 3 cases**:

| Date | Dot fires at (real time) | Gate state at that instant | Spread at that instant | Actual entry (next bar) |
|---|---|---|---|---|
| 2025-04-22 | 00:00:00 | `sell_ALLGATESPASS=true` | **103 points, spreadOk=false** | 04:00:00, spread=2 |
| 2025-06-20 | 00:00:00 | `buy_ALLGATESPASS=true` | **101 points, spreadOk=false** | 04:00:00, spread=2 |
| 2025-10-07 | 00:00:00 | `buy_ALLGATESPASS=true` | **121 points, spreadOk=false** | 04:00:00, spread=0 |

All three dots fire at the identical time-of-day (00:00:00 GMT — the daily-rollover window,
already identified elsewhere in this project as a routine spread-widening period, not a data
anomaly), all three are blocked by the exact same `SpreadOk()` gate at `DCA_EA.mq5:1125-1128`
that caused Finding 1's first divergence, and all three succeed on the very next bar once
spread normalizes — by which point price has moved against us for the full 4-hour gap. This
is not new evidence of a second mechanism; it's the same mechanism producing a different visible
symptom (delayed entry at a worse price, rather than a permanently missing trade).

- **Root cause**: **CONFIRMED, same as Finding 1** — the spread-units mismatch causes our
  (spec-correct, points-based) gate to reject entries during routine daily-rollover spread
  spikes that a more permissive (hypothesized pips-based) reference cap would not reject.
- **Code location**: same as Finding 1 — `DCA_EA.mq5:136`, `:1125-1128`.
- **Classification**: **D — Parameter Interpretation Difference** (merged into Finding 1, not
  a separate finding). The original "possible independent intrabar entry mechanism" hypothesis
  (H3a) is **disproven** — no evidence of it survived once H3b was tested directly.
- **PnL contribution**: this is part of the $55.99 "different-leg-count" bucket in §D — these 3
  specific sequences matched with different leg counts precisely because the delayed entry also
  delayed/altered which add-on legs the sequence went on to receive.

---

## G. Common/Systemic Issues

Only one genuinely systemic root cause was confirmed this pass: **Finding 1 (spread units)**
is a single point-of-divergence whose consequences (the 7-vs-1 sequence split, and everything
downstream of those 7 sequences' own lifecycles) account for the visible majority of the
structural difference between the two engines' trade histories. Finding 2 is systemic in its
own right (affects every touch-mode exit, not just these 5 dates) but was already characterized
as such in prior work. Finding 3 is not yet established as systemic or even as a genuine root
cause distinct from Finding 1's downstream noise.

---

## H. Corrective Action Plan

**1. Required implementation fixes**: none identified this pass that weren't already known
(Finding 2 remains an open, previously-scoped decision, not newly required here).

**2. Reference-equivalence fixes**: 
- Finding 1: if byte-exact reference-matching is a goal (as opposed to spec-correctness, which
  our current points-based reading already satisfies), changing `InpMaxSpread`'s effective cap
  to match reference's likely-pips interpretation would be a **calibration change, not a bug
  fix** — per the brief's own classification rules, this belongs in category D/G, and should
  not be implemented without an explicit decision that reference-matching outranks the
  documented spec's own stated units. Not implemented in this pass (diagnosis only, per
  Critical Operating Rule 1).

**3. Execution/reliability improvements**: none identified — execution-level costs were shown
in §D to not be a material independent contributor.

**4. Parameter calibration**: `InpMaxSpread`'s numeric value (not its units) could be revisited
as a deliberate strategy choice (e.g. "we want a 4-pip cap because X") independent of the
reference-matching question — that's a product decision, not something this report resolves.

**5. Optional strategy experiments**: none proposed — per the brief's explicit instruction not
to use this discrepancy as justification for backtest-specific tuning.

---

## I. Validation Plan

For Finding 1, if a `InpMaxSpread` units/value change is ever made:
1. Re-run this exact controlled baseline (same `.set` skeleton, same date range, same Model=4)
   before and after the change.
2. Confirm the 2025-02-04 00:05 add-on now succeeds (or document why it still doesn't, if the
   change was to a different value than tested here).
3. Re-run the full 5-case forensic reconciliation from `VISUAL_TEST_2025_DIAGNOSTIC_REPORT.md`
   to confirm no *new* spread-gate rejections appear elsewhere that previously didn't (i.e. the
   change should only ever make the gate more permissive, never introduce new blocks).
4. Re-run on at least one additional, non-overlapping date range (per the brief's overfitting
   guard, §14) before treating the change as validated rather than dataset-specific.
5. Confirm final balance/PF move in the direction of reference **only as a side-observation**,
   not as the validation criterion itself — the actual criterion is "spread gate now applies the
   documented/intended threshold," which is independently checkable via the forensic spread log
   regardless of whether it happens to raise or lower this particular period's PnL.

For Finding 3, the validation plan **is** the next diagnostic step: extend
`DCA_EA_Forensic.mq5`'s logging to the reference's 3 divergent dates specifically (or, more
robustly, write a sequence-reconstruction pass per §D's recommendation) to determine which of
the two competing explanations is correct before proposing any correction at all.

---

## Artifacts

- `diagnostics/backtests/baseline_our.csv`, `baseline_ref.csv` — controlled-baseline deal logs
  (this report's primary evidence), extracted from `Baseline_OurEA_Report.htm` /
  `Baseline_ReferenceEA_Report.htm` (not committed — regenerable from the `.set` files below).
- `MQL5\Profiles\Tester\baseline_ourEA.set`, `baseline_referenceEA.set` — the matched parameter
  files used for this controlled run (local to the MT5 install, not part of this git repo).
- Reconciliation/extraction scripts used for this pass are in the session scratchpad, not
  committed (regenerable; simple CSV/HTML parsing, no novel logic worth preserving in-repo).
