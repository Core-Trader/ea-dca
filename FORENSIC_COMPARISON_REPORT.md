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
