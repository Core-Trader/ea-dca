# Forensic Comparison — `DCA_EA.mq5` vs. Reference (`Jagfx-DCA_V2.0.4`)

**Test conditions (identical for both):** EURUSD, H4, 2026.01.01–2026.09.13, Every tick based on real ticks, $100,000 deposit, 1:30 leverage, FTMO-Server4, `default.set` parameters.

**Sources:**
- Benchmark: `C:\FTMO Global Markets MT5 Terminal\benchmark.html` (Expert: `Jagfx-DCA_V2.0.4` — the closed-source, no-`.mq5`-available original this project reimplements)
- Current EA: `C:\FTMO Global Markets MT5 Terminal\DCA_EA_EURUSD_H4_2026.htm` (Expert: `DCA_EA`, this repo's `src/experts/DCA_EA.mq5`, Phases 1–4)

---

## 0. Parameter verification (done first, since everything downstream depends on it)

Every one of the 120 `Inp*` values in the benchmark's Settings block was extracted and diffed against `default.set` line by line (scripted diff, not eyeballed). **Result: zero differences.** The one extra parameter the benchmark has (`InpLicenseKey=`, blank) is a licensing field with no equivalent in our EA and no bearing on trading logic.

**Conclusion: parameter mismatch is ruled out as an explanation for any of the findings below.**

---

## 1. Benchmark Results

| Metric | Value |
|---|---|
| Total Net Profit | 258.57 |
| Gross Profit | 344.84 |
| Gross Loss | -86.27 |
| Profit Factor | 4.00 |
| Expected Payoff | 5.50 |
| Sharpe Ratio | 1.74 |
| Recovery Factor | 0.85 |
| Total Trades | 47 |
| Short Trades (won %) | 17 (58.82%) |
| Long Trades (won %) | 30 (73.33%) |
| Total Deals | 94 |
| Profit Trades (% total) | 32 (68.09%) |
| Loss Trades (% total) | 15 (31.91%) |
| Largest profit trade | 60.02 |
| Largest loss trade | -19.90 |
| Average profit trade | 10.78 |
| Average loss trade | -5.58 |
| Max consecutive wins ($) | 5 (52.53) |
| Max consecutive losses ($) | 4 (-42.89) |
| Balance Drawdown Maximal | 42.94 (0.04%) |
| Equity Drawdown Maximal | 305.89 (0.31%) |
| Margin Level (min) | 8946.90% |

## 2. Current EA Results

| Metric | Value |
|---|---|
| Total Net Profit | 96.45 |
| Gross Profit | 153.73 |
| Gross Loss | -57.28 |
| Profit Factor | 2.68 |
| Expected Payoff | 2.41 |
| Sharpe Ratio | 2.28 |
| Recovery Factor | 2.35 |
| Total Trades | 40 |
| Short Trades (won %) | 13 (61.54%) |
| Long Trades (won %) | 27 (70.37%) |
| Total Deals | 80 |
| Profit Trades (% total) | 27 (67.50%) |
| Loss Trades (% total) | 13 (32.50%) |
| Largest profit trade | 21.56 |
| Largest loss trade | -18.57 |
| Average profit trade | 5.69 |
| Average loss trade | -4.28 |
| Max consecutive wins ($) | 4 (25.05) |
| Max consecutive losses ($) | 2 (-8.15) |
| Balance Drawdown Maximal | 18.57 (0.02%) |
| Equity Drawdown Maximal | 41.09 (0.04%) |
| Margin Level (min) | 42774.96% |

## 3. Side-by-Side Comparison

| Metric | Benchmark | Current EA | Difference | Assessment |
|---|---|---|---|---|
| Total Trades | 47 | 40 | -7 (-14.9%) | Confirmed implementation difference — root cause §5 |
| Short Trades | 17 | 13 | -4 | Confirmed implementation difference — root cause §5 |
| Long Trades | 30 | 27 | -3 | Confirmed implementation difference — root cause §5 |
| Total Deals | 94 | 80 | -14 | Consequence of the trade-count difference (both show exactly 2 deals/trade — see §4 note) |
| Total Net Profit | 258.57 | 96.45 | -162.12 (-62.7%) | Consequence of fewer/smaller/differently-timed trades, not an independent bug |
| Profit Factor | 4.00 | 2.68 | -1.32 | Consequence |
| Largest profit trade | 60.02 | 21.56 | -38.46 | Consequence — largest reference trade (deal 87, $59.94) comes from an 8-way simultaneous close of a large basket our EA's architecture can't build (§5) |
| Win rate | 68.09% | 67.50% | -0.59pp | Not meaningfully different — NOT a strong signal on its own |
| Avg profit / avg loss | 10.78 / -5.58 | 5.69 / -4.28 | smaller both sides | Consequence of smaller average sequence size (fewer parallel/concurrent baskets accumulating) |
| Max consecutive wins/losses | 5 / 4 | 4 / 2 | fewer both | Consequence of fewer total trades |
| Margin Level (min) | 8946.90% | 42774.96% | current EA uses far less margin | Consequence — current EA never runs 2–3 parallel baskets, so peak concurrent exposure is much lower |

**Do not read the profit/drawdown/ratio deltas as independent findings** — they are statistically downstream of the two structural divergences identified in §4–§5. Fixing those is a precondition for any of these numbers being comparable again.

---

## 4. First Point of Divergence

Full deal-by-deal reconstruction of both engines' first 14 deals (chronological):

| # | Benchmark | Current EA |
|---|---|---|
| Trade 1 (BUY open) | **2026.01.02 04:00:06**, 0.01 lot @ 1.17609 | **2026.01.02 12:00:00**, 0.01 lot @ 1.17219 |
| Trade 2 (add) | 2026.01.05 20:00:05, 0.02 lot @ 1.17145 | 2026.01.05 20:00:05, 0.02 lot @ 1.17145 *(identical)* |
| Trade 3 (add) | 2026.01.12 04:00:00, 0.03 lot @ 1.16562 | 2026.01.12 04:00:00, 0.03 lot @ 1.16562 *(identical)* |
| Next event | 2026.01.16 16:00:01: **adds a 4th trade (0.04)** AND **opens a second, independent BUY sequence (0.01)** at the same instant | **2026.01.12 15:47:13** (intrabar): **closes the entire 3-leg sequence** (-2.53, -3.58, +12.12) |

**The earliest confirmed divergence is on the very first trade of the entire test**: the reference opens its first BUY on the H4 candle starting **2026.01.02 04:00**, ours opens on the candle starting **2026.01.02 12:00** — two H4 bars (8 hours) later, at a different price (1.17609 vs. 1.17219).

Trades 2 and 3 (the first two add-ons) then land on **exactly the same bars, at exactly the same prices and lot sizes**, in both engines. This is an important, non-obvious fact: it shows the two engines' bar-close signal detection is behaviorally identical for add-on purposes on these two bars — the divergence is isolated to (a) whatever gate decides the very first entry of a brand-new sequence, and (b) what happens after trade 3, described next.

**The second, independent divergence** (chronologically the next one, and the more consequential one) is the sequence's exit: our EA closes the whole 3-leg basket intrabar at **15:47:13 on 2026.01.12** — the same day as the 3rd add-on, mid-candle, not at any H4 boundary. The reference does not exit here at all; it keeps the basket open and adds a 4th and then a 5th (parallel-sequence) trade over the following four days.

---

## 5. Root Cause

### 5.1 — Sequence exit fires on a live, still-forming bar instead of a closed one (CONFIRMED, high-confidence)

`BBCentreExitConditionTick()` (`src/experts/DCA_EA.mq5:1812-1819`):

```mql5
bool BBCentreExitConditionTick(bool isBuy)
  {
   if(g_bbHandle == INVALID_HANDLE) return(false);
   double mid[1];
   if(CopyBuffer(g_bbHandle, 0, 0, 1, mid) <= 0) return(false);   // shift 0 = CURRENT, still-forming bar
   double price = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   return(isBuy ? price >= mid[0] : price <= mid[0]);
  }
```

This is called from `HandleBBCentreOrQQE50()` **every tick**, whenever `InpBBExitOnBreach = true` (the default). It reads the Bollinger middle band of the bar that is still forming (`shift = 0`) and compares it to the live bid — meaning the exit can fire and reverse based on a transient, mid-candle price excursion that the bar may not even close beyond.

The 2026.01.12 15:47:13 timestamp is not an H4 boundary (H4 bars close at 00:00/04:00/08:00/12:00/16:00/20:00) — it is a mid-candle tick, which is only possible because this check runs on every tick, not on bar close.

**Design history:** this was my own interpretation of `InpBBExitOnBreach`, made explicit and flagged as an assumption at the time (`DCA_EA_Analysis_Report.md` §22, item 3: *"`InpBBExitOnBreach` governs only the Centre Band strategy... Opposite Band is always a live/per-tick breach check"*). No spec text was available to confirm this reading — I inferred "breach" meant "react intrabar in real time," treating the toggle as an **intrabar-vs-bar-close timing switch**.

**Alternative reading, now supported by the reference's observed behavior:** the input's own name is *"Exit on Breach, **Not Just Close**"* — read literally, "Breach" (a touch) and "Close" (the closing price) are two candidate **price thresholds** to test **against the same closed bar**, not two different **timings**. Under this reading, both modes would evaluate once per closed H4 bar: `InpBBExitOnBreach=true` → did the bar's high/low *touch* the middle band; `=false` → did the bar's *close* cross it. Neither mode would ever fire mid-candle. This reading is consistent with every other exit/entry check in the EA (all bar-close-driven) and with the reference's observed refusal to exit despite price clearly trading back through the middle band intrabar on 2026.01.12 (evidenced by our own EA — reading the *same* market data — triggering there).

**Classification: Confirmed implementation difference, Potential implementation bug.** The mechanism (live-tick vs. bar-close evaluation) is confirmed by direct code inspection. Whether the *specific* fix (switch to a bar-close touch check) is exactly what the reference does internally is inference from behavior, since the reference's source is not available — labeled as inference, not fact, in the recommendation below.

### 5.2 — The EA cannot open more than one sequence per direction under `default.set` (CONFIRMED, code-level fact, independent of any market-data interpretation)

`FindOpenSequenceWithRoom()` (`src/experts/DCA_EA.mq5:990-1002`):

```mql5
int FindOpenSequenceWithRoom(bool isBuy)
  {
   int total = isBuy ? ArraySize(g_buySequences) : ArraySize(g_sellSequences);
   for(int i = 0; i < total; i++)
     {
      int  count       = isBuy ? g_buySequences[i].count          : g_sellSequences[i].count;
      bool partialDone  = isBuy ? g_buySequences[i].partialCloseDone : g_sellSequences[i].partialCloseDone;
      if(partialDone) continue;
      if(InpMaxTradesPerSequence <= 0 || count < InpMaxTradesPerSequence)   // <-- always true when InpMaxTradesPerSequence == 0
         return(i);
     }
   return(-1);
  }
```

`default.set` has `InpMaxTradesPerSequence = 0` ("unlimited"). With that value, **the `count < InpMaxTradesPerSequence` branch is never reached — the function always returns the first open, not-partial-closed sequence it finds**, for as long as one exists. `TryEnterSequence()` only ever considers opening a genuinely new sequence (the branch that checks `InpMaxSequencesPerDirection`) when this function returns `-1` — which, under `default.set`, can only happen when **zero** sequences are open in that direction. **`InpMaxSequencesPerDirection` (default `3`, meaning up to 3 concurrent baskets per direction) is never read at all along this path while any sequence is open.** This is not inference — it follows directly from the code as written, for any market data.

The benchmark's deal log directly falsifies the "only one sequence at a time" model: at **2026.01.16 16:00:01**, it both adds a 4th trade to the existing basket (0.04, continuing the 1/2/3/4 Linear ladder) **and** opens a second, independent 0.01-lot BUY at the identical timestamp — a trade that cannot be explained as an add-on to the first basket (whose ladder position would call for 0.05, not 0.01). The two baskets are then confirmed as genuinely independent because they **close at different times**: the second (0.01-lot) basket closes alone on 2026.01.20 00:05:00 for +2.14, while the first (4-leg) basket closes four hours later, at 12:00:00, for a combined result across all 4 legs. The same pattern repeats at 2026.06.12 00:05:00 (a 3rd add to one basket and a 2nd add to a second, concurrent basket, fired simultaneously), and those two baskets likewise close at different times (08:00:00 vs. 04:00:00 on 06.15).

**Classification: Confirmed implementation difference, Potential implementation bug (missing feature).** The reference clearly implements `InpMaxSequencesPerDirection` as a genuine concurrent-basket limit; the current EA's decision rule for "does this signal start a new sequence or add to an existing one" only ever produces one basket at a time whenever `InpMaxTradesPerSequence` is unlimited — which is the shipped default.

### 5.3 — First-trade entry timing (2 H4 bars later than the reference)

**Confirmed fact:** the very first BUY of the whole test fires 8 hours (two H4 bars) later in the current EA than in the reference, at a different price.

**Unable to determine the exact mechanism without additional evidence.** Trades 2 and 3 (the next two add-ons) land on *identical* bars/prices/lots in both engines, which rules out a wholesale QMP/BB/QQE calculation discrepancy — whatever differs is specific to the **very first entry of a sequence when no sequence yet exists in that direction**. Candidate mechanisms, none of which I can confirm or rule out without indicator buffer values for the 2026.01.01 20:00 through 2026.01.02 12:00 H4 candles:
- `CentreCrossReady()` (`:1009-1015`) or `NoTriggerOnCentreBreachOk()` (`:1017-1021`) — both are new-sequence-only gates that could have rejected an earlier, otherwise-valid signal that the reference accepted.
- A difference in when the BB lower-band "armed" latch (`g_bbBuyArmed`, set in `BBBuyBreach()`, `:882`) actually turns on, versus whatever latch/condition the reference uses for a sequence's very first trade.

**What additional evidence would resolve this:** QMP dot state and BB upper/middle/lower values for EURUSD H4 at 2026.01.01 20:00, 2026.01.02 00:00, 04:00, and 08:00 (the four candles preceding each engine's first entry). This would show directly which bar the reference's signal actually fired on and which of our gates (if any) blocked it on that same bar.

---

## 6. Evidence

- Parameter diff: scripted line-by-line comparison of 120 `Inp*` values, `default.set` vs. benchmark.html Settings block — 0 differences.
- Full Orders/Deals tables extracted from both `.htm` reports (UTF-16 → UTF-8 converted, read directly) — the specific deal rows cited above (benchmark deals 2–11, 53–59; current-EA deals 2–7) are quoted verbatim from those tables.
- `src/experts/DCA_EA.mq5` lines 882, 930–939, 990–1002, 1009–1021, 1812–1825, read directly from the current repo state.
- `DCA_EA_Analysis_Report.md` §22 item 3, confirming the `InpBBExitOnBreach` interpretation was my own unverified assumption at the time it was written.

No claim above rests on an assumption about the reference's internal source code — the reference is closed-source (`.ex5` only, confirmed: no `.mq5` exists anywhere in this environment for `Jagfx-DCA_V2.0.4`) and every conclusion about it is drawn strictly from its observable trade log and its published parameter set.

---

## 7. Recommended Fix (not yet applied)

Two independent, minimal changes, addressing §5.1 and §5.2 separately (do not conflate them into one change):

1. **§5.1 — make `BBCentreExitConditionTick()` evaluate the closed bar, not the live one.** Change its `CopyBuffer(g_bbHandle, 0, 0, 1, mid)` to shift `1`, and compare against the closed bar's high/low (touch) rather than live bid/ask — i.e., make it structurally match `BBCentreExitConditionBar()`'s data source but keep the "touch" (high/low) threshold instead of that function's "close" threshold. Concretely: `InpBBExitOnBreach=true` → `(isBuy ? g_bar1High >= g_bbMiddle1 : g_bar1Low <= g_bbMiddle1)`; `=false` → the existing `BBCentreExitConditionBar()` close-based check, unchanged. This removes the need for a separate "tick" vs. "bar" code path entirely — both become bar-close checks differing only in threshold (touch vs. close), evaluated once per bar inside the existing per-bar snapshot refresh.
2. **§5.2 — let `TryEnterSequence()` choose between adding to an existing sequence and starting a new parallel one, instead of `FindOpenSequenceWithRoom()` unconditionally claiming any non-full sequence.** The minimum change is to decide new-vs-add based on whether the **current open sequence count for that direction is below `InpMaxSequencesPerDirection`**, not solely on whether an existing sequence has trade-count room. This requires establishing the exact selection rule (e.g., does a fresh dot always prefer starting a new sequence when the cap allows it, only falling back to an add-on once the cap is reached?) — the benchmark's dual-fire timestamps show *both* an add and a new-sequence-open can happen from the same bar, which the current single-branch `if (room exists) add-on; else new` structure cannot express. This needs a design decision, not just a one-line patch — I have not implemented it, per your instruction to complete the analysis first.

**Not recommended:** do not "fix" §5.3 (the entry-timing gap) until the additional indicator-value evidence described above is gathered — changing a new-sequence gate now, without knowing which one (if any) is actually responsible, risks introducing a change that happens to shift the first trade's timing without being the reference's actual rule.

---

## 8. Fix Verification — §5.1 applied (2026.09.14)

`BBCentreExitConditionTick()` was changed exactly as recommended: it now reads the closed-bar snapshot (`g_bar1High`/`g_bar1Low` vs. `g_bbMiddle1`) instead of live `CopyBuffer(shift=0)` + live bid/ask. Recompiled clean (0 errors/warnings), re-ran the identical backtest.

**Aggregate result — moved in the right direction, as expected, not fully closed (expected, since §5.2 is still open):**

| Metric | Before fix | After fix | Benchmark |
|---|---|---|---|
| Total Trades | 40 | **45** | 47 |
| Total Deals | 80 | **90** | 94 |
| Total Net Profit | 96.45 | **105.28** | 258.57 |
| Profit Factor | 2.68 | 2.61 | 4.00 |

**The originally-cited motivating example (the 2026.01.12 sequence) was traced again and is *not* fully resolved by this fix in isolation — for a specific, now-understood reason, not a flaw in the fix itself:**

The sequence still closes at the identical intrabar timestamp, 2026.01.12 15:47:13. Tracing why: `HandleBBCentreOrQQE50()`'s Recovery Mode logic latches `recoveryModeActive = true` the first time `conditionMet` is observed true *while the sequence is not yet at breakeven+buffer*, and once latched, every subsequent tick only re-checks the live breakeven+buffer threshold (`GetSequenceProfitPips(...) >= InpBreakevenBufferPips`) — not `conditionMet` again. Since this sequence needed Recovery Mode (it was not yet profitable enough when the centre-band condition first became true), the *exact* moment `conditionMet` first fired (live tick, pre-fix, vs. bar-close, post-fix) stopped mattering the moment the Recovery latch engaged — both versions arm the same latch on 2026.01.12, and the actual close is then governed purely by live price crossing the same breakeven+buffer level on the same tick data, landing on the same timestamp in both versions. **The fix is behaving correctly; this particular instance simply isn't sensitive to it.** The fix *does* change outcomes for sequences that reach breakeven+buffer immediately when the condition first fires (no Recovery Mode needed) — accounting for the aggregate improvement above.

**Stronger evidence that §5.2 (not §5.1) now dominates the remaining gap in this exact region:** once our sequence closed on 01.12, the *next* signal (2026.01.16 16:00:01) opened a fresh sequence that matches the benchmark's **second, parallel** sequence almost exactly:

| | Open time/price | Close time/price | Profit |
|---|---|---|---|
| Benchmark's 2nd (parallel) sequence | 01.16 16:00:01 @ 1.16191 | 01.20 00:05:00 @ 1.16405 | 2.14 |
| Our post-fix sequence | 01.16 16:00:01 @ 1.16191 | 01.20 00:05:00 @ 1.16409 | 2.18 |

Same bar, same price, same close bar, same close price (4-point difference — noise-level, likely spread/rounding), same profit to within 4 cents. **Our engine is correctly reproducing the reference's second concurrent basket — it just has nowhere to also keep tracking the first one**, because it closed sequence 1 outright instead of letting it run in parallel (§5.2). This is direct, trade-level confirmation that §5.2 — not any remaining exit-timing issue — is the dominant cause of the still-open gap in this region, and very likely elsewhere in the test.

**Recommendation:** proceed to §5.2 next. §5.1 is verified correct and should be kept as-is.

---

## 9. §5.2 Implementation and a Second, Related Bug Found During Verification

Implemented the proposed rule: `AddOnToAllOpenSequences()` (loops every open, non-full sequence on a dot, instead of routing to only the first one found) and `TryOpenNewSequence()` (independent check, gated by `NewSequenceGatesPass()` + the `InpMaxSequencesPerDirection` cap), both triggered from the same dot in `ProcessNewBar()` rather than as a mutually-exclusive either/or. `FindOpenSequenceWithRoom()` (the function that made this structurally impossible) was removed as dead code.

**First backtest after this change moved the wrong way** (trades 45→44, not toward 47) — tracing why surfaced a second, independent bug in the same area:

`CentreCrossReady()` (`InpRequireCenterBandCross`, on by default) was a **stateless positional check** — "is price currently below/above the middle band right now" — rather than a stateful latch. During a sustained excursion (e.g., 2026.01.02–01.20, while price stays below the middle band the whole time), this check is true on almost every bar, so as soon as `TryOpenNewSequence()` could actually be reached (after the §5.2 structural fix), it fired far too often — e.g. an extra, incorrect new sequence opened on 2026.01.05 (confirmed in the deal log: a spurious 0.01 BUY alongside the correct 0.02 add-on), which the reference does not do. This exact simplification had already been flagged as a candidate wrong assumption when it was written (§21 of this same report, "implemented as a positional check... rather than a stateful latch").

**Fix:** replaced it with `g_centreCrossReadyBuy`/`g_centreCrossReadySell` — latches that start `true`, are consumed (`false`) when a new sequence opens in that direction, and only re-arm once price *closes on the opposite side of the middle band* at least once afterward (`UpdateCentreCrossReadiness()`, called once per bar). This requires a genuine recovery-then-reversal before a second parallel sequence can be justified, rather than merely "still on the same side of centre as before." Added to state persistence (`SaveState`/`LoadState` GLOBAL line, 2 new trailing fields) for consistency with the other latches.

### Verification

| Metric | §5.1 only | §5.2 (structural, before CentreCrossReady fix) | §5.2 complete | Benchmark |
|---|---|---|---|---|
| Total Trades | 45 | 44 | **47** | **47** |
| Total Deals | 90 | 88 | **94** | **94** |
| Total Net Profit | 105.28 | 112.11 | 114.89 | 258.57 |
| Profit Factor | 2.61 | 2.98 | 3.03 | 4.00 |
| Short Trades | — | — | 12 | 17 |
| Long Trades | — | — | 35 | 30 |

**Total Trades and Total Deals now match the benchmark exactly (47/94).** Re-traced the 2026.01.02–01.20 region deal-by-deal against the benchmark: the spurious Jan 5 sequence is gone, and the 2026.01.16 16:00:01 sequence (opened fresh after our sequence 1 closed on 01.12, per the still-open §5.1-adjacent Recovery Mode nuance discussed in §8) again matches the benchmark's second sequence's open bar/price exactly.

**Not yet resolved:** the long/short split differs (12 short / 35 long here vs. 17 short / 30 long in the benchmark) despite the identical total, and net profit is still well below the benchmark (114.89 vs. 258.57). The total count matching while the direction split doesn't strongly suggests the remaining gap is concentrated in **which** signals resolve to a trade on each side — consistent with, and possibly the same root cause as, the still-unresolved §5.3 (first-trade entry-timing gap). **Recommended next step:** revisit §5.3 with this new evidence — check whether an equivalent "same bar, different H4 candle" timing gap exists on the SELL side's first trades, the way it does on BUY's.

---

## 10. §5.3 Resolved — Root Cause Confirmed via Indicator Dump, Fix Applied

**New free evidence, no backtest needed:** compared each engine's first-ever SELL trade using deal logs already on hand. **Identical in both** — 2026.01.21 12:00:00 @ 1.17034, exact match. This immediately narrowed the problem: the entry-timing gap is not a general "first trade of any sequence" defect (the SELL side's very first sequence entry is perfect) — it is isolated specifically to the BUY side's very first trade of the *entire* backtest.

**Diagnostic built to close the gap:** a throwaway EA (`Diag_QMP_BB_Dump.mq5`, deleted after use — not part of this repo) dumped the exact QMP dot state and BB upper/middle/lower for every closed H4 bar from 2025.12.01 through 2026.01.05, run via a fast (`Model=2`, Open-prices-only) Strategy Tester pass. Run with the user's explicit approval.

**What it showed, bar by bar:**

| Bar (open time) | Low | Close | BB Lower | Low ≤ Lower? | Close ≤ Lower? | QMP dot |
|---|---|---|---|---|---|---|
| 2025.12.31 16:00 | 1.17203 | 1.17361 | 1.17423 | Yes | Yes | — |
| 2025.12.31 20:00 | 1.17303 | 1.17454 | 1.17403 | Yes | **No** | — |
| 2026.01.02 00:00 | 1.17447 | 1.17611 | 1.17392 | No | No | **UP** |
| 2026.01.02 04:00 | 1.17506 | 1.17514 | 1.17383 | No | No | — |
| 2026.01.02 08:00 | 1.17206 | 1.17215 | 1.17366 | **Yes** | **Yes** | — |

The QMP UP dot fires on the 2026.01.02 00:00 bar — confirmed the moment the 04:00 bar starts, i.e. 2026.01.02 04:00:0x. **That is exactly the reference's entry time.** A genuine "touched-and-closed-beyond" BB breach (both Low and Close under the lower band) doesn't occur until the 08:00 bar — confirmed at 12:00:00, **exactly our EA's entry time**, since our EA correctly held the dot pending until a real zone breach armed it.

The only candidate breach *before* the dot is 2025.12.31 16:00 — a genuine touch-and-close-beyond breach, four bars earlier. If our sticky zone-armed latch (no time limit, by design — the same rule confirmed correct everywhere else in this report) had been active at that point, it would have stayed armed right through to the dot and produced an immediate 04:00 entry, matching the reference. **It wasn't active, because the latch's initial value at EA/test start was `false`.** The 2025.12.31 16:00 breach happened, in effect, "before the EA existed" from the backtest's point of view — there is no bar before the `FromDate` for the EA's own `OnTick()`-driven latch-tracking to have observed it, even though the *indicator* itself has all the historical data it needs.

**Root cause (confirmed, not inferred):** `g_bbBuyArmed`/`g_bbSellArmed`/`g_qqeBuyArmed`/`g_qqeSellArmed` initialized to `false`. Every *other* new-sequence-only latch in the file (`g_centreCrossReadyBuy`/`Sell`, `g_reentryReadyBuy`/`Sell`) was already deliberately initialized to `true`, with an explicit comment explaining why: so the very first sequence at EA/test start isn't artificially blocked. The zone-armed latches were the one place that principle wasn't applied — an inconsistency in the original design, not a spec ambiguity requiring further inference.

**Fix applied:** `g_bbBuyArmed = true, g_bbSellArmed = true, g_qqeBuyArmed = true, g_qqeSellArmed = true` (was `false` for all four). Compiles clean (0 errors/warnings). Not yet re-verified against the benchmark — pending the user's decision on whether to run that backtest now or run it themselves.

**Why this doesn't reopen a live-trading risk:** in live/demo use, `LoadState()` overwrites this default with the actual persisted latch value on every restart after the first; the `true` default only ever matters for a genuinely fresh chart with no state file yet — the same situation the other three latches were already designed for.

---

## 11. §5.3 Fix Verification — Blanket Pre-Arm Was Wrong, Refined, and a Second Bug Found

**First verification result:** the blanket "all four latches start true" fix produced 49 trades / 98 deals — overshooting the benchmark's 47/94 (which the pre-§5.3 code had matched exactly). Tracing why: our SELL side's first-ever trade already matched the benchmark exactly *before* this fix (2026.01.21 12:00:00 @ 1.17034, with `g_bbSellArmed` starting `false`). Pre-arming it unconditionally introduced a spurious extra SELL sequence on 2026.01.02 16:00:00 that the reference never opens — the fix was correct for BUY (which needed a pre-armed start) but wrong for SELL (which didn't).

**Refined fix:** `InitializeZoneLatchesFromHistory()`, called once from `OnInit()` before `LoadState()`, scans a bounded 10-bar window of real historical bars immediately preceding the EA's first bar and computes each of the four latches' actual starting value from genuine breach/oversold/overbought conditions — instead of assuming a fixed default (true or false) for all of them. This is the same "no time limit" carry-forward rule already confirmed correct for in-test breaches everywhere else in this report, just applied retroactively to the handful of bars right before the EA's own tracking begins. The 10-bar window is a deliberately generous, clearly-flagged margin over the one confirmed data point (the reference's BUY entry is explained by a breach exactly 2 bars before its first live bar) — not a reverse-engineered exact constant.

**Second verification result:** 48 trades / 96 deals — down from 49/98, but still one extra trade over the benchmark's 47/94. The BUY-side fix held exactly (2026.01.02 04:00:06 @ 1.17609, matching the reference precisely) and the spurious Jan 2 SELL sequence was gone, but a *new* spurious sequence appeared: a second BUY sequence opened on 2026.01.05 20:00:05 (0.01 lot) alongside the correct add-on to sequence 1 (0.02 lot) — something the reference does not do.

**Tracing this surfaced a second, independent, confirmed bug** — not a further tuning problem with the lookback window. `UpdateCentreCrossReadiness()`:

```mql5
// as written (wrong):
if(g_bar1Close > g_bbMiddle1)      g_centreCrossReadySell = true;
else if(g_bar1Close < g_bbMiddle1) g_centreCrossReadyBuy  = true;
```

This has BUY and SELL swapped — a close *below* centre was arming BUY-readiness, when `CentreCrossReady()`'s own logic (a new BUY sequence requires `g_centreCrossReadyBuy`) and the function's own doc comment both require the opposite: BUY-readiness should arm on a close *above* centre (a genuine recovery, away from buy territory, that a fresh down-move can later reverse from). With the bug, `g_centreCrossReadyBuy` was true on every single bar throughout the sustained downtrend from Jan 2 onward — defeating the gate exactly the way the original stateless positional check (§9) did, just via an inverted stateful assignment instead. This is a plain implementation bug (evidenced by direct contradiction between the code and its own adjacent comment/caller logic), not a modeling ambiguity requiring further inference. Fixed by swapping the two assignments.

**Status:** both fixes applied and compiled clean (0 errors/warnings). Re-verification backtest pending — to be run by the user this time, per the standing "always ask before running a backtest" rule.

**Unrelated, noted in passing:** two display-input defaults (`InpShowTrailingStops`, `InpShowDisplayPanel`) were found changed to `false` outside this session, in both the live file and the archived `DCA_EA_V1.mq5` snapshot. Confirmed with the user and kept as-is — not reverted, and not related to any of the trading-logic findings above.

---

## 12. Correction — the "CentreCrossReady Swap Fix" in §11 Was Itself Wrong

**The "second bug" reported in §11 was a misdiagnosis.** Verifying it produced a clear regression: 42 trades / 84 deals — *worse* than both the benchmark (47/94) and the un-swapped version's 48/96. Re-checked the reasoning: during a sustained one-directional move (exactly the Jan 2–20 stretch under investigation — close stayed below the middle band on every single bar), **both** orientations of the assignment are continuously true for whichever side matches the trend. The swap therefore could not have been the actual mechanism behind the Jan 5 extra-sequence symptom it was diagnosed against — that diagnosis skipped checking what the *un-swapped* code would have done in the same stretch before concluding the swap was the fix. Reverted to the original orientation (confirmed via `git diff` against the exact commit that had already been backtested to 48/96 — logic is byte-identical, so no new backtest was needed to confirm the revert).

**Where this leaves §5.3, honestly:**

| Configuration | Trades / Deals | Jan 2 BUY entry timing | Jan 5 extra sequence |
|---|---|---|---|
| Zone latches start `false` (pre-§5.3) | **47 / 94** (exact benchmark match) | Wrong — 2 bars late (the originally-diagnosed bug) | Absent |
| + `InitializeZoneLatchesFromHistory()` (bounded lookback) | 48 / 96 | **Correct** — matches reference exactly | Present (not yet explained) |

These two configurations trade off against each other, and the correct choice is not simply "whichever count is closer to 47" — per the task's own instruction not to chase final statistics. The bounded-lookback fix is principled (a real historical scan, not a hardcoded assumption) and directly, verifiably fixes the specific bug that motivated the whole §5.3 investigation. The Jan 5 extra sequence it introduces is a **new, distinct, not-yet-diagnosed** question — plausibly not a bug at all: a genuine in-test BB breach *does* occur at 2026.01.02 08:00–12:00, and by the EA's own already-validated "sticky latch, no time limit" rule (confirmed correct everywhere else in this report), that breach legitimately re-arms the zone. Whether the reference treats that same event as a valid trigger for a second sequence this soon is unknown — resolving it would need the same kind of targeted evidence-gathering as the rest of §5.3 (e.g., checking whether the reference has some minimum elapsed-time-or-distance rule between a direction's sequences that isn't captured by any input already inventoried in this project).

**Recommendation:** keep `InitializeZoneLatchesFromHistory()` — it is verified correct for the bug it targets, unlike the reverted swap. Treat the Jan 5 question as a new, separate, open item rather than continuing to iterate on §5.3 itself.

---

## 13. P&L Gap Root-Caused — Concentrated in 3 Events, Same Pattern Every Time

**Method:** rather than a per-trade diff (which is unreliable wherever concurrent same-direction sequences overlap — see the FIFO-reconstruction caveat below), compared the running account-balance curve from both engines' full deal logs directly (the `Balance` column already in each `.htm` report), merge-walked in calendar time, and ranked every closing event by how much it widened or narrowed the cumulative gap. Verified against the latest committed code state (bounded lookback + un-swapped `CentreCrossReady`, 48 trades / $113.76) vs. the benchmark (47 trades / $258.57). No new backtest was needed — both full deal logs were already on hand.

**Result: three events account for ~$118 of the ~$145 total gap (over 80%):**

| Event | Gap contribution | Benchmark | Ours |
|---|---|---|---|
| 2026.01.20 12:00 | **+$55.76** | 4-leg BUY basket (0.01→0.02→0.03→0.04, opened 01.02–01.16) closes together for +$56.02 | Same starting sequence fragments: closes early (01.12, +$2.60) via a separate small piece, then a fresh sequence opens 01.16 and closes small (01.20) |
| 2026.07.30 00:05 | **+$33.13** | Clean 3-leg basket (0.06 lot) closes for +$33.45 | Same window splits into ~5 legs across what looks like 2 concurrent sequences, netting +$9.94 |
| 2026.09.02 12:00 | **+$29.78** | Single largest leg of the entire test: +$60.17 on one 0.06-lot leg, the payoff of a large accumulated basket | Corresponding basket is much smaller |

**Every one of these follows the identical pattern**: the reference keeps deepening *one* basket into a larger position before it finally exits; ours either exits the original basket earlier or fragments the accumulation across multiple smaller concurrent sequences. The first event is the *exact same* 2026.01.02–01.20 sequence traced throughout §4–§12 of this report — confirming the "Jan 5 extra sequence" question deprioritized in §12 as a minor, unexplained edge case is **not minor**: it's the same underlying mechanism, and it's responsible for the majority of the entire profit gap, not a one-trade curiosity.

**Caveat on methodology:** an earlier attempt at full sequence-by-sequence reconstruction (FIFO-matching open legs to closing clusters) produced two internal volume-mismatch warnings and is known to mis-draw sequence boundaries wherever multiple concurrent same-direction sequences overlap (it has no way to distinguish which open leg belongs to which of several simultaneously-open baskets). The balance-curve comparison above does not depend on correct sequence boundaries — it only sums realized P&L in calendar order — so it is reliable for locating *when* the gap opens, even though the FIFO reconstruction's sequence-level labels (used only for descriptive color in the table above) should be treated as approximate.

**Recommendation:** the Jan 5 question from §12 should be promoted back to the top investigative priority — it is very likely the same root cause behind all three events above, not an isolated curiosity. The next concrete step is understanding precisely why our EA's basket-accumulation-vs-fragmentation behavior differs from the reference's in these specific windows (all three involve either a second concurrent sequence opening, or an existing sequence exiting sooner than the reference's equivalent).

---

## 14. Root Cause Found and Fixed — Recovery Mode Was Live-Price-Driven, Not Bar-Close-Driven

Dug into the §13 #1 event (the 2026.01.02–01.20 sequence) directly, with a targeted diagnostic dumping closed-bar High/Low/Close and BB Middle for 2026.01.14–01.21.

**What it showed:** the H4 bar `2026.01.20 04:00` closes at **1.16632** — the first bar where `close >= middle` (the base exit condition, already bar-close driven since §5.1). The H4 bar `2026.01.20 08:00` closes at **exactly 1.17264** — and the benchmark's actual exit for this sequence is **1.17264 at 12:00:00**, the instant the next bar opens. That is not a coincidence: the reference's exit price is literally the prior bar's close, confirmed at the next bar's open, for *both* the base condition and the Recovery Mode breakeven+buffer check.

**Root cause:** `HandleBBCentreOrQQE50()`'s Recovery Mode breakeven+buffer check used `GetSequenceProfitPips()` — live bid/ask, checked every tick — so the moment intrabar price crossed the buffer threshold (computed from this sequence's real average entry: ≈1.16735), it closed immediately. That happened inside the `2026.01.20 08:00–12:00` bar, at `09:22:15`, roughly one bar and ~53 pips earlier and less favorably than the reference. The base condition itself was already bar-close driven since §5.1, but the InpBBExitOnBreach=true "touch" variant (`BBCentreExitConditionTick`, using bar high/low rather than close) was still being used for it and firing a bar earlier than the close-based version would have.

**Fix:** (1) `HandleBBCentreOrQQE50()`'s base condition now always uses `BBCentreExitConditionBar()` (close-based), regardless of `InpBBExitOnBreach` — the touch-based variant is removed as unused; there is no positive evidence for it, only evidence against it, and `InpBBExitOnBreach=false` remains untested since only `=true` (`default.set`'s value) was ever exercised against the benchmark. (2) A new `GetSequenceProfitPipsFromClose()` replaces the live-price check for Recovery Mode's breakeven+buffer test specifically — every *other* exit strategy (Fixed Target, Risk Reduction, Trailing) still uses the live-price `GetSequenceProfitPips()`, since `default.set`'s `InpExitStrategy=0` never exercises those against the benchmark and there is no evidence either way for them.

### Verification

| Metric | Before this fix | After this fix | Benchmark |
|---|---|---|---|
| Total Net Profit | $113.76 | **$281.16** | $258.57 |
| Profit Factor | 2.63 | **4.02** | **4.00** |
| Expected Payoff | 2.37 | 4.85 | 5.50 |
| Short Trades | 12 | **17** | **17** |
| Long Trades | 36 | 41 | 30 |
| Total Trades / Deals | 48 / 96 | 58 / 116 | 47 / 94 |

Profit Factor is now a near-exact match, and Short Trades matches exactly — strong confirmation this was the dominant remaining bug, not a coincidental statistical shift. Total profit moved from 56% under the benchmark to ~9% over it.

**New, well-scoped remaining discrepancy:** the entire trade-count excess (11 trades) is on the LONG side specifically (41 vs. benchmark's 30) — SHORT is now a perfect match (17/17). This narrows any further investigation to whatever differs specifically in BUY-direction sequence formation, rather than a general mechanism.

---

## 15. Fix — CentreCrossReady Was a Positional Latch, Not a Crossing Detector

Investigated the §14 long-side-excess finding by re-examining the Jan 2–20 window deal-by-deal. The main 4-leg BUY sequence now closes at 1.17263 @ 2026.01.20 12:00:00 (benchmark: 1.17264 @ 12:00:00 — confirms §14's fix is working). But two spurious extra BUY sequences were still opening mid-trend: one at 2026.01.05 20:00:05, one at 2026.01.12 04:00:00 — the benchmark has neither in this window (only the main sequence plus one parallel sequence starting 2026.01.16).

**Root cause:** `UpdateCentreCrossReadiness()` armed each direction's readiness flag based on which side of the centre band price was **currently** on (`close > middle` → arm SELL, `close < middle` → arm BUY), re-evaluated every closed bar. During the Jan 2–20 downtrend, close sat below the middle band on essentially every bar, so `g_centreCrossReadyBuy` was continuously re-armed the entire time — never meaningfully "consumed and required to re-earn readiness via a genuine reversal," despite that being the gate's own documented purpose. This is a positional check, not a crossing detector, and the flaw exists under either buy/sell orientation (consistent with §12's finding that swapping the assignment didn't fix the symptom either — both orientations are "stuck true" for whichever side matches the trend).

**Fix:** replaced the positional check with a true crossing detector. A new global `g_prevCentreSide` tracks which side of the centre band the previous closed bar was on; a readiness flag now only arms on an observed **transition** (`side != g_prevCentreSide`, both sides known), not merely on "currently on this side." Buy/sell mapping is unchanged from the empirically-validated orientation. Compiled clean (0 errors/warnings).

### Verification

| Metric | Before this fix (§14 state) | After this fix | Benchmark |
|---|---|---|---|
| Total Net Profit | $281.16 | $243.67 | $258.57 |
| Profit Factor | 4.02 | 3.71 | 4.00 |
| Short Trades | 17 | 16 | 17 |
| Long Trades | 41 | 33 | 30 |
| Total Trades / Deals | 58 / 116 | 49 / 98 | 47 / 94 |

**Mixed result, reported honestly:** Total trade count moved substantially closer to the benchmark (58→49 vs. target 47), and the long-side excess this section set out to fix shrank from +11 to +3 (41→33 vs. target 30) — clear evidence the crossing-detector model is closer to correct than the positional-latch model it replaced. However, Short Trades regressed off its previous exact match (17→16) and Profit Factor moved further from the benchmark (4.02→3.71 vs. target 4.00). Net profit is now under-benchmark ($243.67 vs $258.57) rather than over, reversing the direction of the §14 miss.

**Deal-log check on the specific Jan 5 / Jan 12 sequences this section targeted:** the Jan 5 fragmentation is confirmed fixed — deals #2/#3/#4/#6 now form one clean 4-leg main sequence (0.01→0.02→0.03→0.04) with no early split. The Jan 12 sequence is **not** fully fixed: a second sequence still opens at 2026.01.12 20:00:01 (0.01 lot) and adds a leg at 2026.01.16 16:00:01 (0.02 lot), closing 2026.01.20 08:00:00. The benchmark's one parallel sequence in this window starts 2026.01.16 — so our EA is still opening this second sequence's first leg **4 days too early** (01.12 vs 01.16), even though it no longer also fragments the main sequence. This looks like a distinct, narrower remaining timing bug in the same area (something else — not `CentreCrossReady` — is independently arming a new-sequence gate on 01.12), not yet root-caused.

**Recommendation:** keep this fix — it is principled (a genuine crossing detector matches the gate's documented intent, unlike the positional check it replaced) and demonstrably shrinks the long-side excess without reintroducing the Jan 5 fragmentation. The Short-Trades/Profit-Factor regression and the residual Jan 12-vs-Jan 16 timing gap are new, narrower open items for further investigation rather than reasons to revert — per the standing instruction not to chase final statistics or force a match, this trade-off is documented rather than papered over.
