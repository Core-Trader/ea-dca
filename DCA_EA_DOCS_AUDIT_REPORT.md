# DCA_EA.mq5 — Audit Against `docs/` (EA User Guide.docx + DCA EA Walkthrough.docx)

**Method:** both Word documents were extracted to plain text and read in full (not re-used from earlier session summaries, since one of those summaries — on "Exit on breach" — turned out to be wrong when checked against the actual guide text). The User Guide is treated as authoritative per the request; the Walkthrough is a shorter, casual companion video transcript that itself says less precisely the same things.

Findings are ordered by how much they could change trading behavior, per the request. Format per finding: **Severity → Location → Documented requirement → Actual implementation → Impact → Recommended action.**

---

## CRITICAL

### C1. Breakeven vs. breakeven+buffer conflated — affects 3 of 6 exit strategies plus Partial Close
**Severity: Critical.**
**Location:** `HandleBBCentreOrQQE50()` (BB Centre Band / QQE 50+Recovery) and `HandleBBOpposite()` (BB Opposite Band) — the `atBreakeven`/`GetSequenceProfitPips(...) >= InpBreakevenBufferPips` check in both.
**Documented requirement** (EA User Guide, Recovery Mode Settings section, quoted in full because the exact wording matters):
> "There are 2x ways the trade sequence could close using these exit strategies... **The 1st type of close** using these exit strategies is simply by a breach of the desired level **AND if the sequence is at overall break even or profitable**, then that sequence will be closed. End of story.. **The 2nd type of close** using these exit strategies needs an alternate trade management strategy for when the desired level is breached **and the trade sequence is not at overall break even or profitable**. The EA will recognise this and then start to look for an overall break even level **plus** the number of pips you entered in the Recovery Buffer above Breakeven field."

This describes **two different thresholds** depending on which situation applies: the *first* time the exit condition fires, closing only requires breakeven-or-better (profit ≥ 0). The **buffer is specifically the fallback target for Recovery Mode** — it only applies once the sequence has already been recognized as not-yet-profitable and entered the "keep taking trades until X" state.

**Actual implementation:** the code applies the **same** `>= InpBreakevenBufferPips` threshold on *every* evaluation, including the very first one:
```mql5
bool atBreakeven = GetSequenceProfitPipsFromClose(isBuy, idx) >= InpBreakevenBufferPips;
if(!atBreakeven) { recoveryModeActive = true; return; }
```
A sequence that's, say, 3 pips in profit (breakeven-or-better, per the guide's "1st type") the moment the condition fires does **not** close — it's incorrectly routed into Recovery Mode and keeps adding trades, exactly as if it were still underwater, until it separately reaches the full buffer.

**Impact:** this raises the bar for a first-time close on every sequence using BB Centre Band, BB Opposite Band, or QQE 50+Recovery — the three most commonly used exit strategies — by the full buffer amount (10 pips in `default.set`). It also gates `ExecutePartialCloseIfDue()`, since Partial Close is only reached after this same check passes. The practical effect is: more sequences pushed into Recovery Mode than should be, each one taking extra add-on trades it shouldn't, extending sequence lifetimes, and shifting exit prices/timing broadly — not a narrow edge case. This is very plausibly the reason this session's three different attempts at fixing the BB Centre Band touch-mode condition mechanism (a naive live check, an arm/stop mechanism, and the correct guide-derived breach latch) all produced nearly identical aggregate backtest results ($89/$88/$90 net profit) despite being structurally very different — the condition-trigger was never the dominant lever; this shared downstream gate was.

**Recommended action:** track whether `recoveryModeActive` was already `true` *before* this tick's evaluation. If not (first time the condition has fired for this sequence), require only `profit >= 0`. If yes (already in Recovery Mode from a prior evaluation), require the full buffer, as now. This applies identically to `HandleBBCentreOrQQE50()` and `HandleBBOpposite()`.

---

### C2. Step-Based lot sizing formula doesn't match the guide's own worked example
**Severity: Critical.**
**Location:** `ComputeBaseLotForNewSequence()`, `LOT_STEP_BALANCE`/`LOT_STEP_EQUITY` branch:
```mql5
int steps = (int)MathFloor(accountValue / InpStepAmount);
base = InpInitialLot + steps * InpLotPerStep;
```
**Documented requirement:** "For example, for every $4000 you have in your account, you may wish to risk 0.02 lots. So when your account balance reaches **$8000, then your base lot would double to 0.04 lots**, and when the balance got up to **$12000, then the base lot would be 0.06 lots**."

Working this through with `InpStepAmount=4000`, `InpLotPerStep=0.02`: at $8000 (2 steps), the guide says lot = 0.04 = `2 × 0.02` — no separate base-lot term added. At $12000 (3 steps), lot = 0.06 = `3 × 0.02` — again pure `steps × lotPerStep`.

**Actual implementation:** adds `InpInitialLot` on top of `steps × InpLotPerStep`. With `InpInitialLot`'s default (0.01), the code would compute 0.01+0.04=0.05 at $8000 and 0.01+0.06=0.07 at $12000 — both **off by exactly `InpInitialLot`** from the guide's own numbers.

**Impact:** every trade size in Step-Balance/Step-Equity mode is wrong by a constant offset — this compounds across every trade in every sequence for the life of the account, directly changing risk and P&L. Untested in this project (every backtest so far used `LOT_FIXED`), so this has never surfaced empirically.

**Recommended action:** drop the `InpInitialLot +` term for the step-based modes — `base = steps * InpLotPerStep`, then apply the existing `InpMaxInitialLot` cap and `NormalizeLot()` as now. Worth confirming with a targeted single-trade diagnostic at a known account balance before shipping the fix, given how explicit the guide's numbers are.

---

### C3. Session Profit Limit doesn't stop add-ons to already-open sequences
**Severity: Critical (risk-control feature not fully doing what it's documented to do).**
**Location:** `SessionProfitLimitReached()` is checked only in `NewSequenceGatesPass()` (used by `TryOpenNewSequence()`); `AddOnToAllOpenSequences()` never checks it.
**Documented requirement:** "Once that target is met, the EA will **stop taking new trades in the sequence** and will close that sequence at the next opportunity, and no new sequences will be commenced until the next start time."

"Stop taking new trades **in the sequence**" is specifically about add-ons to an *existing* sequence, distinct from "no new sequences" which is stated separately in the same sentence. The guide describes two things this feature should do; the code only does one.

**Actual implementation:** once the daily profit target is hit, no *new* sequence can start, but every already-open sequence keeps adding DCA legs exactly as if the limit had never been reached.

**Impact:** for a feature whose entire purpose is capping daily risk/exposure once a profit goal is met, this is a meaningful gap — an already-open sequence can keep averaging down (adding risk) well past the point the user configured the EA to stop for the day.

**Recommended action:** add a `SessionProfitLimitReached()` check to `AddOnToAllOpenSequences()`, gating new legs on already-open sequences the same way it already gates new sequences. "Close that sequence at the next opportunity" most likely just means "let its own normal exit condition close it" (no evidence of a forced early close), so no change needed there.

---

### C4. First Profitable Close checks live price every tick, not on bar close
**Severity: Critical for this specific strategy (never tested in this project, so currently silent).**
**Location:** `HandleFirstProfitable()`:
```mql5
void HandleFirstProfitable(bool isBuy, int idx)
  {
   if(GetSequenceProfitMoney(isBuy, idx) > 0.0)
      CloseSequenceAndCleanup(isBuy, idx, "first profitable close");
  }
```
Called every tick via `CheckExitsPerTick()`.
**Documented requirement:** "It doesn't matter if there is 1x trade or 20x trades in the sequence, but **if a candle closes** and the sequence is in overall profit, then the sequence will close."

"If a candle closes" is explicit bar-close timing, matching how every other exit condition in this EA that has real evidence behind it (§13/§14's forensic finding for BB Centre Band, the QQE 50 condition, the newly-corrected touch-mode breach latch) turned out to actually work.

**Actual implementation:** live, every-tick, using instantaneous floating profit (`PositionGetDouble(POSITION_PROFIT)` via `GetSequenceProfitMoney`) — will close the instant profit ticks above $0.00, mid-bar.

**Impact:** untested in this project, so no empirical evidence yet of how large the divergence would be — but structurally this is the exact same live-vs-bar-close bug class that §13/§14 found to be the single largest fix in the whole forensic investigation (PF 2.63→4.02), now present, unfixed, in a strategy nobody has looked at yet.

**Recommended action:** change to bar-close: evaluate `GetSequenceProfitMoney` (or an equivalent computed from `g_bar1Close`) once per closed bar, not every tick.

---

## HIGH

### H1. Entry zone-breach latch may be over-constrained (requires close beyond the band, not just a touch)
**Severity: High — affects entry timing across every trade in every test, but plausible-but-unconfirmed.**
**Location:** `BBBuyBreach()` / `BBSellBreach()`:
```mql5
bool BBBuyBreach()  { return(g_bbSnapshotValid && g_bar1Low  <= g_bbLower1 && g_bar1Close <= g_bbLower1); }
```
**Documented requirement** (QQE Settings section, explicitly extended to BB in the same paragraph): "When I use the term 'breached', all it means is a touch of that nominated level... **It doesn't have to close at 65 or higher, just as long as it hits that level at some point.** And when I say 'confirmed', that means at the close of the current price candle... **The same applies to the BB**, but instead it is the upper and lower bands."

Read closely, "confirmed... at the close" describes *when* you can be sure the touch is real and settled (using the finalized, closed bar's data rather than a still-forming one) — not a requirement that the close price itself also be beyond the band. The guide's own framing ("it doesn't have to close at 65 or higher, just has to hit it") argues the opposite of what the code requires for BB.

**Actual implementation:** requires **both** the bar's Low/High touching the band **and** the bar's Close being beyond it — a strictly narrower condition than "touched at any point, confirmed once the bar is final."

**Impact:** this is the entry-side zone-arming latch used for every single trade sequence in the EA — if over-constrained, it delays or occasionally misses arming events the reference EA would register, a first-order effect on entry timing across the whole test. This has never been isolated and tested directly (the many entry-timing investigations earlier in this project focused on `CentreCrossReady` and the startup lookback window, not this specific latch's own high/low-vs-close condition).

**Recommended action:** test relaxing `BBBuyBreach()`/`BBSellBreach()` to drop the `&& close <= lower` / `>= upper` clause, keeping only the Low/High touch, and compare entry timing against the reference EA on a representative window before committing to either version — don't change this from documentation reasoning alone, given how consequential entry-timing changes have been to get right elsewhere in this project (§5.3/§11/§12's saga).

---

### H2. Add-on entries have no retry-after-spread-rejection path
**Severity: High.**
**Location:** `AddOnToAllOpenSequences()` checks `SpreadOk()` once and simply `continue`s past a sequence if it fails — no memory of the missed opportunity. Compare `TryOpenNewSequence()`, which is retried on every subsequent bar via the `g_pendingSignal` latch until it succeeds.
**Documented requirement:** "if the spread goes out to 4 pips during a certain period, then even if a new trade signal is identified by the EA, that trade will not be taken at that time. But **it may be taken at any time later if the spread comes into 3 pips or lower AND the trade signal is still valid**."

The guide describes this as a general property of "a new trade signal," not scoped to new-sequence entries specifically.

**Actual implementation:** a new-sequence entry blocked by spread gets a genuine retry mechanism (the pending-signal latch happens to cover this, even though it wasn't built for that purpose specifically). An add-on blocked by spread on the same bar is simply lost — there's no equivalent latch for add-ons, so that specific DCA leg opportunity never comes back, even if the spread normalizes on the very next bar.

**Impact:** under wide-spread conditions (news events, session opens/closes — exactly when the guide calls this out as most relevant), add-on legs can be silently and permanently skipped in a way the documentation says shouldn't happen.

**Recommended action:** needs a design decision, not just a fix — either extend a pending-retry concept to add-ons per-sequence, or confirm with the reference EA's actual behavior whether add-ons really do retry past a spread rejection before building anything.

---

### H3. Named multiplier system arrays have no documented source
**Severity: High (affects position sizing directly whenever a non-default multiplier system is used).**
**Location:** `BuildMultiplierSequence()` — `MULT_SAFE={1,1,1,2,3,5,8}`, `MULT_FIBONACCI={1,2,3,5,8,13}`, `MULT_AGGRESSIVE={1,2,4,6,10,16}`, `MULT_MARTINGALE={1,2,4,8,16,32}`.
**Documented requirement:** the guide only ever gives numeric sequence *examples* in the context of explaining the Custom option (`1,3,5,8,13` and `2,8,3,10` as illustrations, and separately states the author's own preference is "either 1,3,5,8,13 or 1,2,3,4,5,6,7 (Linear Arithmetic)"). It never states what numbers the **named presets** (Safe, Fibonacci, Aggressive, Martingale) actually contain.
**Actual implementation:** specific arrays chosen for each name, presumably by inference (Fibonacci = classic Fibonacci numbers, Martingale = doubling, etc.) — reasonable guesses, but unconfirmed by any source document.
**Impact:** every trade size in a sequence for four of the six multiplier systems rests on an assumption. `MULT_LINEAR` is the only one textually confirmed (`1,2,3,4,5,6,7`, explicitly named in the guide) — consistent with it being the only one exercised in any backtest so far.
**Recommended action:** this can only be resolved by comparison with the reference EA (open a multi-leg sequence under each named system and diff lot sizes) or by checking whether a `.set` file or other artifact from the original author specifies these arrays explicitly. Flagging as a test item rather than guessing further from documentation, since none exists.

---

## MEDIUM

### M1. A3 from the prior code audit is superseded by C1, not a separate issue
The earlier `DCA_EA_AUDIT_REPORT.md` (§A3) framed `HandleBBOpposite()`'s breakeven check as a live-vs-bar-close timing question, by analogy with §14's fix for BB Centre Band. Having now read the actual guide text, the real issue is C1 above (breakeven vs. breakeven+buffer, not live vs. close) — the same root cause affects `HandleBBOpposite()` identically to the other two strategies. No separate action needed for A3 beyond applying the C1 fix uniformly.

### M2. Risk Reduction's cross-strategy scope is confirmed correct (closes a prior open question)
The earlier code audit (§B2) flagged that Risk Reduction runs regardless of `InpExitStrategy`, unlike Dynamic Stop/Partial Close, and noted it as an unconfirmed assumption. The guide explicitly restricts Dynamic Stop and Partial Close ("They do not work with the First Profitable, Fixed Target, or Pure Trailing Stop exit strategies") but states no equivalent restriction anywhere for Risk Reduction, which is introduced as a fully independent feature. This confirms the current unrestricted behavior is correct as implemented — B2 can be closed, not left open.

### M3. Pure Trailing Stop's "average of all trade entries" wording — confirmed match, closes a prior open question
`DCA_EA_Analysis_Report.md` §18 flagged this as "could be misread literally" and worth a doc clarification. Having read the source directly: "The actual trailing stop level is the average of all the trade entries in the sequence" — this is exactly `avgPrice`, exactly as implemented. Confirmed match, no action needed.

---

## Documentation ambiguities / internal contradictions (as requested)

1. **QQE default level self-contradiction** (already known from earlier project history, reconfirmed here): the guide states "The default settings are 65/35" in one place and "I tend to use the 60/40 levels as my main setting" in another. `default.set` and the code ship 60/40. Not a code bug — just don't "fix" the code to 65/35 based on the first sentence in isolation.
2. **"Exit on breach" — Walkthrough vs. Guide disagree on precision.** The Walkthrough says simply "we exit as soon as price breaches the band, not just on the close" — read in isolation this sounds like immediate/live reaction. The Guide gives a precise, different operational description (sticky bar High/Low latch, evaluated and executed at bar-close, gated on overall profit) — already implemented per that more precise description. Per the instruction to treat documentation as authoritative and the Guide being the detailed spec (the Walkthrough is a casual video transcript), the Guide's version should govern; this is flagged so the disagreement isn't silently lost.
3. **Session Profit Limit's "close that sequence at the next opportunity"** is ambiguous about whether it means "closes via its own normal exit condition, whenever that next happens" (assumed here, and how the existing code already behaves for the sequences it does track) or "force-close immediately once the target is hit." The surrounding sentence structure favors the first reading, but it isn't unambiguous.

---

## Items requiring reference-EA comparison to confirm (consolidated, supersedes/extends the prior report's D-list)

Priority order, by how much a wrong answer would change results:

1. **C1 (breakeven vs. buffer)** — verify against the reference by finding a sequence that closes at a small (< buffer) positive profit on its very first condition-met evaluation; if the reference closes there and our EA (pre-fix) keeps running, that's direct confirmation.
2. **H1 (entry breach: touch vs. touch+close)** — isolate on a bar where price's Low touches the outer band but the bar closes back on the original side; check whether the reference arms its entry zone latch there.
3. **C2 (step-based lot sizing)** — single-trade diagnostic at a known account balance under `LOT_STEP_BALANCE`, compare the resulting lot directly against the reference.
4. **H3 (named multiplier arrays)** — diff lot sizes across a multi-leg sequence for each of Safe/Fibonacci/Aggressive/Martingale.
5. **C4 (First Profitable Close)**, **C3 (Session Profit Limit add-ons)**, **H2 (add-on spread retry)** — each needs a dedicated backtest window engineered to exercise the specific condition (an add-on-eligible bar during a wide-spread period; a sequence still open when the daily profit target is hit; any First-Profitable-Close sequence at all, since none has ever been tested).

---

## Summary

- **4 Critical findings (C1–C4)**, one of which (C1, breakeven-vs-buffer conflation) is very likely the dominant, previously-unidentified explanation for why this session's three different touch-mode condition-mechanism rewrites all landed in the same narrow, wrong aggregate range — it affects three exit strategies and Partial Close simultaneously, independent of which condition-trigger mechanism is used.
- **3 High findings (H1–H3)**, each independently capable of shifting entry timing or position sizing across an entire test.
- **3 Medium findings**, two of which close prior open questions from the earlier code-only audit (B2, and the trailing-stop wording ambiguity) — confirmed correct, not defects.
- **3 documented ambiguities**, flagged rather than resolved by guessing.

No code was modified in the course of this audit, per the request.
