# DCA EA (Jagfx-DCA-EA-V2.0) — Project Analysis Report

**Purpose:** Consolidate the seven project files into a single technical spec ahead of writing the main `.mq5` Expert Advisor, flag gaps/inconsistencies between the files, and list open questions for the stakeholder before development starts.

---

## 1. Executive Summary

The project is a MetaTrader 5 **Dollar-Cost-Averaging (DCA) Expert Advisor** that adds to a losing position in stages ("sequences") using signals from four indicators, then manages the whole sequence to one of six possible exits. Three of the four indicators are custom (`QMP Filter.mq5`, `MACD_Platinum.mq5`, `QQE Adv.mq5`); the fourth (`BB.mq5`) is the stock MetaQuotes Bollinger Bands indicator.

The `default.set` file is effectively the **parameter contract** for the EA — it names ~90 inputs across 20 functional blocks. `EA_User_Guide.docx` is the authoritative behavioral spec (explains *why* and *how* each input works); `DCA_EA_Walkthrough.docx` is a shorter, informal companion covering the same ground, useful for confirming section order and terminology but adding no new information.

None of the files address **state persistence across a terminal restart**, and none show the actual trade-management / position-sizing code — only the indicators that generate entry signals. That logic (sequence tracking, lot sizing, exits, dynamic stop, partial close, risk reduction, session handling) has to be designed and written from scratch based on the guide's prose description.

---

## 2. File-by-File Overview

| File | Type | Role |
|---|---|---|
| `QMP_Filter.mq5` | Custom indicator (chart window) | Combines MACD_Platinum + QQE Adv into single "sync" signal — plots a dot only when both agree. Also computes an optional higher-timeframe (HTF) version of the same dot. This is the actual trade **trigger**. |
| `MACD_Platinum.mq5` | Custom indicator (sub-window) | "Zero-Lag MACD" (DEMA-based when `ZeroLag=true`). Feeds QMP Filter. |
| `QQE_Adv.mq5` | Custom indicator (sub-window) | Modified-RSI oscillator (Wilders-smoothed ATR-of-RSI trend line). Feeds QMP Filter **and** is used a second time, independently, as an entry-zone (overbought/oversold) filter. |
| `BB.mq5` | Custom indicator (chart window) | Stock MetaQuotes Bollinger Bands — SMA middle band ± StdDev. Used as the alternate entry-zone filter to QQE. |
| `default.set` | Config file | The full, exact list of `Inp*` input variable names/defaults for the finished EA — this is the ground truth for what the EA's `input` block must contain. |
| `EA_User_Guide.docx` | Documentation | Full behavioral spec: strategy rationale, every input explained, worked examples (lot multiplier maths, dynamic stop, partial close, recovery buffer), risk warnings. |
| `DCA_EA_Walkthrough.docx` | Documentation | Shorter narrative covering the same input blocks in the same order — good for confirming grouping/order, adds nothing new. |

---

## 3. System Architecture (Indicator Dependency Map)

```
                     ┌───────────────────┐
                     │  MACD_Platinum.mq5 │
                     └─────────┬─────────┘
                               │ (blue/orange buffers)
┌───────────────────┐         ▼
│  QQE Adv.mq5 (#1)  ├──►  QMP_Filter.mq5  ──► up/dn dots = TRADE TRIGGER
│  SF1/RSI8/WP3       │      (also HTF dots, not used by main EA — see Q1)
└───────────────────┘

┌───────────────────┐
│  QQE Adv.mq5 (#2)  │  SF7/RSI14/WP1 — standalone, used ONLY for
│  standalone entry   │  overbought(60)/oversold(40) zone detection
└───────────────────┘

┌───────────────────┐
│  iBands() (native)  │  Period 35 / Dev 2.25 / Applied Price = High
│  standalone entry   │  used for upper/lower band breach zone detection
│  [confirmed: native, no BB.mq5 file needed]
└───────────────────┘

┌───────────────────┐
│  iATR() (native)    │  ONE shared handle — feeds Fixed Target(ATR),
│                     │  Trailing Start/Distance(ATR), Min Signal Distance(ATR)
└───────────────────┘

┌───────────────────┐
│  iMA() (native)     │  MA Filter, first trade only
└───────────────────┘
```

**Key insight:** the EA needs **two independent QQE Adv instances** with different settings — one embedded inside QMP Filter (fixed at 1/8/3, just for dot generation) and one standalone at the user's chosen 7/14/1 (or whatever `InpQQESmoothingPeriod`/`InpQQERSIPeriod`/`InpQQEMultiplier` are set to) for the overbought/oversold entry-zone logic. These are easy to conflate since both are "QQE Settings" in the guide.

---

## 4. Complete Input Parameter Inventory

Extracted from `default.set`, cross-referenced against `EA_User_Guide.docx` for meaning/type.

### Position Sizing
| Variable | Default | Notes |
|---|---|---|
| `InpMultiplierSystem` | 1 | Enum: Safe / Linear / Fibonacci / Aggressive / Martingale / Custom |
| `InpFibSequence` | `"1,3,5,8,13"` | **Retyped to string, name kept as-is** (final decision — see §13, item 2). Only parsed when `InpMultiplierSystem` = Custom. Last value in the sequence repeats for any trade beyond the array length. |
| `InpInitialLot` | 0.01 | Base lot for trade #1 of every sequence |
| `InpLotSizeMode` | 0 | Enum: Fixed / %Balance / %Equity / Step-Balance / Step-Equity |
| `InpLotPercent` | 15.0 | Used only in %Balance/%Equity modes |
| `InpStepAmount` | 1000.0 | Account increment for step-based sizing |
| `InpLotPerStep` | 0.01 | Lot increase per step |
| `InpMaxInitialLot` | 1.0 | Cap on trade #1 lot in step mode; 0 = uncapped |

### Trading Parameters
| Variable | Default | Notes |
|---|---|---|
| `InpMagicNumber` | 123456 | Must be unique per chart instance |
| `InpSlippage` | 3 | Points |
| `InpMaxSpread` | 40 | Points (not pips — 10 points = 1 pip on 5-digit) |
| `InpMaxTradesPerSequence` | 0 | 0 = unlimited |
| `InpMaxSequencesPerDirection` | 3 | Concurrent Buy sequences and Sell sequences cap |
| `InpTradeDirection` | 0 | Enum: Both / Buy Only / Sell Only |
| `InpAllowBuySellAtSameTime` | true | **Requires a hedging account — see Q7** |
| `InpUserComment` | "Jagfx-DCA-EA-V2.0" | Trade comment |

### Indicator Mode
| Variable | Default | Notes |
|---|---|---|
| `InpIndicatorMode` | 0 | Enum: BB Only / QQE Only / Both — must match `InpExitStrategy` family (see §5.4) |

### QMP Filter Settings (feeds `iCustom(..., "QMP Filter", ...)`)
`InpQMPFast`=12, `InpQMPSlow`=26, `InpQMPSmooth`=9, `InpQMPSF`=1, `InpQMPRSI_Period`=8, `InpQMPWP`=3

### Bollinger Band Settings
`InpBBPeriod`=35, `InpBBDeviation`=2.25, `InpBBAppliedPrice`=3 (`PRICE_HIGH`), `InpUseBBWidthFilter`=false, `InpBBMinWidthPercent`=0.5, `InpRequireCenterBandCross`=true, `InpNoTriggerOnCentralBandBreach`=true, `InpRequireBBBandTouchForReentry`=false, `InpBBExitOnBreach`=true, `InpAlwaysCloseOnOppositeBand`=false

### QQE Settings (standalone instance)
`InpQQEOverbought`=60.0, `InpQQEOversold`=40.0, `InpQQESmoothingPeriod`=7 (→ QQE Adv's `SF`), `InpQQERSIPeriod`=14, `InpQQEMultiplier`=1 (→ QQE Adv's `WP`), `InpRequireQQEScenarioBForReentry`=false

### Exit Strategy
| Variable | Default | Notes |
|---|---|---|
| `InpExitStrategy` | 0 | Enum, 6 values — see §5.4 for the full compatibility matrix |
| `InpUseDynamicStop` | false | Only valid with `InpExitStrategy` = BB Centre Band or QQE50+Recovery; mutually exclusive with Partial Close |
| `InpDynamicStopDistancePips` | 20.0 | |

### Recovery Mode
`InpBreakevenBufferPips`=10.0 (used by BB Centre, BB Opposite, and QQE50+Recovery exits)

### Exit Parameters — Fixed Target
`InpFixedTargetType`=1 (Currency/Pips/ATR), `InpProfitTargetCurrency`=50.0, `InpProfitTargetPips`=50.0, `InpATRPeriod`=14, `InpATRMultiplier`=2.0, `InpShowTakeProfitLine`=true (pips/ATR modes only, per guide — not shown in Currency mode), `InpTakeProfitLineColor`=16748574

### Exit Parameters — Trailing Stop
`InpTrailingStartPips`=50, `InpTrailingStartDollars`=50.0 (whichever triggers first wins, other ignored), `InpTrailingStepPips`=40 (**likely = "Trailing Distance" — see Q3**), `InpUseATRForTrailingStart`=false, `InpTrailingStartATRMultiplier`=1.5, `InpUseATRForTrailingDistance`=false, `InpTrailingDistanceATRMultiplier`=1.0, `InpTrailingStepBlockPips`=1 (granularity of trail adjustment)

### Risk Reduction
`InpUseRiskReduction`=false, `InpRiskReductionMinTrades`=5, `InpRiskReductionBufferPips`=10.0

### Trading Session Times
`InpUseTimeFilter`=false, `InpTimeReference`=0 (Broker/Local/GMT), `InpGMTOffset`=0, `InpTradingStartTime`="08:00", `InpTradingEndTime`="20:00", `InpTradeMonday..InpTradeSunday`=true (7 toggles)

### End of Day / End of Week
`InpUseEOD`/`InpUseEOW`=false, `InpEODTime`="20:00"/`InpEOWTime`="22:00", `InpEODAction`/`InpEOWAction`=0 (Enum: Close if Profitable / Close if Losing / Close All / Do Nothing)

### Advanced Settings
- **Partial Close:** `InpUsePartialClose`=false, `InpPartialClosePercent` — **now a 2-value enum, `None` / `50%`** (decided; default `None`), `InpPartialCloseBreakevenStepPips`=10.0
- **Signal Distance Filter:** `InpUseMinimumSignalDistance`=false, `InpMinDistancePips`=10.0, `InpUseATRForMinDistance`=false, `InpMinDistanceATRMultiplier`=1.5
- **Session Profit Limit:** `InpStopAfterProfitPerSession`=0.0
- **Entry Options:** `InpAllSignalsMatchEntryCriteria`=false (forces 1 sequence/direction; subsequent trades require a fresh BB/QQE breach + QMP dot, not just a QMP dot)
- **HTF Direction Filter:** `InpTradeInHigherTFDirection`=false, `InpHigherTimeframe`=16388 (`PERIOD_H4`)
- **MA Filter (1st trade only):** `InpUseMAFilter`=false, `InpMAFilterBehaviour`=0 (Buy Above/Sell Below vs Buy Below/Sell Above), `InpMAPeriod`=50, `InpMAMethod`=1 (`MODE_EMA`), `InpMAAppliedPrice`=1 (`PRICE_CLOSE`)

### Display (cosmetic only — no trading logic)
On-screen line toggles/colors for trailing, breakeven, breakeven-buffer, risk-reduction, sequence start/end lines; and the info panel position/colors.

---

## 5. Key Functional Requirements Extracted from the Guide

### 5.1 Entry Logic
- A trade only fires on a **closed-candle** QMP dot (QMP Filter does not repaint).
- **BB mode:** dot is only actionable if price has (breached the corresponding outer band at some point) — buy on lower-band touch + blue dot, sell on upper-band touch + red dot.
- **QQE mode:** dot is only actionable once the standalone QQE has breached the overbought/oversold level. A dot that appears *before* the breach remains valid once the breach later confirms (no time limit on this).
- **Both mode:** BB drives the breach, but the standalone QQE must **also** have breached its matching level for the signal to confirm — QQE acts as a filter on top of BB.
- "Breach" = touched-and-closed on that side of the level on a completed candle — a mid-candle touch that closes back on the wrong side does not count.

### 5.2 Position Sizing
Multiplier sequence (safe/linear/fib/aggressive/martingale/custom) applied to `InpInitialLot`; once the sequence array is exhausted, all subsequent trades reuse the **last** number in the array (worked example confirmed in the guide, §"Position Sizing").

### 5.3 Sequence-Level Filters (before a trade is allowed)
1. Max spread / slippage gate
2. Max trades per sequence / max sequences per direction
3. Center-band-cross required before new sequence (`InpRequireCenterBandCross`)
4. No first trade if signal candle already breached center band (`InpNoTriggerOnCentralBandBreach`)
5. Band-touch or QQE-extreme required before re-entry after a sequence closes
6. Minimum signal distance (pips or ATR) from the previous trade in the same sequence
7. HTF direction filter
8. MA filter (first trade of sequence only)
9. `InpAllSignalsMatchEntryCriteria` — if true, subsequent trades in a sequence need a fresh BB/QQE breach, not just a QMP dot

### 5.4 Exit Strategy Compatibility Matrix
| Exit Strategy | Requires Indicator Mode | Dynamic Stop allowed? | Partial Close allowed? |
|---|---|---|---|
| BB Centre Band | BB or Both | ✅ | ✅ |
| BB Opposite Band | BB or Both | ❌ | ❌ |
| QQE 50 + Recovery | QQE or Both | ✅ | ✅ |
| First Profitable Close | Any | ❌ | ❌ |
| Fixed Profit Target | Any | ❌ | ❌ |
| Pure Trailing Stop | Any | ❌ | ❌ |

**The EA must validate this combination at `OnInit()`** and refuse to run (Alert + `INIT_PARAMETERS_INCORRECT`) if e.g. Indicator Mode = QQE Only but Exit Strategy = BB Opposite Band.

### 5.5 Dynamic Stop (state machine, not a static field)
- Arms only when the chosen exit condition (BB centre / QQE 50) is met **and** sequence is in profit.
- On arm: places a trailing stop N pips behind price (favorable direction only).
- If sequence profit falls back to ≤ 0: stop is fully removed and the sequence resumes normal signal-taking (can add more trades).
- Closes the sequence outright if price touches the stop level.

### 5.6 Partial Close
- Only runs with BB Centre Band / QQE50+Recovery exit strategies, only when ≥ 2 trades are open and the exit condition is met in profit.
- Closes all trades but one; the "None"/"50%" choice determines whether the last trade is also partially reduced.
- With only 1 trade in the sequence when triggered: it isn't closed — instead a breakeven (± trailing) stop is applied to it directly.

### 5.7 Recovery / Breakeven Buffer
Applies to BB Centre, BB Opposite, and QQE50+Recovery exits: if the exit condition fires while the sequence is below breakeven+buffer, the EA keeps taking **any** new QMP dot in the sequence's direction (ignoring the BB/QQE zone condition) until breakeven+buffer is reached, then closes.

### 5.8 Session / EOD / EOW / Profit-Limit Controls
All independent of each other; EOD/EOW act on open sequences but don't prevent existing sequences from completing (except "Close All" action). Session profit limit halts **new sequences**, not existing ones.

---

## 6. Technical Specifications / MQL5 Coding Standards to Follow

- **No MQL4-style indicator calls.** Create every indicator handle once in `OnInit()` (`iCustom`, `iRSI`, `iATR`, `iMA`) and retrieve values every tick via `CopyBuffer()` — exactly the pattern already used correctly in `QMP_Filter.mq5`. Release every handle in `OnDeinit()` with `IndicatorRelease()`.
- **Custom `iBarShift`** — MT5 has no built-in equivalent; `QMP_Filter.mq5` already implements one for HTF alignment. Reuse/adapt that exact function for the EA's own HTF Direction Filter rather than writing a second implementation.
- **Trading calls** should use `CTrade` (`Trade.mqh`) rather than raw `OrderSend()` structs, for cleaner error handling and retry logic.
- **Position bookkeeping**: since MT5 allows both netting and hedging accounts, and this EA needs to hold multiple simultaneous same-direction *and* opposite-direction positions on one symbol, group open positions by `(Symbol, Magic Number)` and iterate with `PositionsTotal()` / `PositionGetTicket()` — never assume ticket-order.
- Use `ArraySetAsSeries(..., true)` consistently on any price/time/indicator array being read most-recent-first (as the existing indicators do).
- Signal detection should run on **new-bar-close only** (compare current bar time to a stored `datetime`), while trailing stop / dynamic stop / session-time / EOD checks need to run every tick.
- Validate account type at `OnInit()` — `AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING` — since same-symbol opposite positions require a hedging account (see Q7).
- Validate `AccountInfoInteger(ACCOUNT_TRADE_EXPERT)` / `TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)` at `OnInit()` and warn if algo-trading isn't enabled (the guide explicitly tells users to enable this manually).

---

## 7. Existing Custom Indicator Code Review

| File | Strengths | Issues Noted |
|---|---|---|
| `QMP_Filter.mq5` | Clean handle lifecycle, correct MT5 `OnCalculate` recalculation-limit pattern, working custom `iBarShift`, no repaint (confirmed by candle-close-only logic) | None functional |
| `MACD_Platinum.mq5` | Correct DEMA-based zero-lag implementation | Header comment still says `.mq4` (leftover from an MT4 port — cosmetic); malformed `http//` link property |
| `QQE_Adv.mq5` | Correct Wilders-smoothed QQE trend-line algorithm | None functional — but note it must be instantiated **twice** with different parameter sets (see §3) |
| `BB.mq5` | Standard, well-tested MetaQuotes implementation | Unmodified stock indicator — **confirmed: not used by the EA**; native `iBands()` replaces it, file kept in the project as reference only |

---

## 8. Risk Management Guidelines (from the source docs — to be encoded in EA logic/alerts, not just documentation)

- No stop-loss by design — the EA's entire risk model rests on lot sizing, sequence caps, and the exit strategies. This should be called out prominently in code comments and in a startup `Alert()`/`Print()` disclaimer, not silently assumed.
- Adding positions against an open loss increases margin usage — `InpMaxSpread`, `InpMaxTradesPerSequence`, and `InpMaxSequencesPerDirection` are the primary margin-risk controls and should be enforced strictly (reject a new trade rather than silently resizing it).
- Guide flags jurisdiction-specific hedging restrictions (notably US brokers) and prop-firm drawdown/consistency rules as user responsibilities, not EA-enforced — worth a one-line reminder in the user-facing docs, not in code.
- Session profit limit and EOD/EOW actions are the built-in "circuit breakers" — worth confirming these default to sensible off-states (they do: `InpStopAfterProfitPerSession=0.0`, `InpUseEOD/EOW=false`).

---

## 9. Compatibility Considerations

1. **Hedging account preferred** for `InpAllowBuySellAtSameTime=true` and for holding multiple sequences per direction — MT5 netting accounts cannot hold two positions in opposite directions on the same symbol. **Decision: soft warning only, not a hard `OnInit()` failure** — the EA will run on a netting account but log a clear warning that opposite-direction behavior will differ from the guide's description.
2. **Two QQE Adv instances** with different inputs must coexist without cross-contamination — confirm the `iCustom` calls pass distinct parameter sets and are stored in separate handle variables.
3. **Shared ATR handle**: `InpATRPeriod` (defined once, under Fixed Target settings) is reused by Fixed Target/ATR mode, Trailing Start/Distance ATR options, and the Signal Distance ATR option — one `iATR()` handle, read in multiple places, rather than three separate handles.
4. **Indicator files must ship alongside the EA** in `MQL5/Indicators/` with exact matching names (`"QMP Filter"`, `"MACD_Platinum"`, `"QQE Adv"`) since `iCustom()` calls in `QMP_Filter.mq5` reference these by string name — any rename breaks the chain silently (MT5 just returns an invalid handle at runtime, no compile error). **`BB.mq5` is no longer part of this dependency chain** now that Bollinger Band values come from native `iBands()`.
5. **Template/indicator settings drift**: the guide repeatedly warns that any indicators visually displayed on the chart must use the *same* settings as the EA's inputs, or visual inspection during testing/live use becomes misleading. Not an EA code issue, but worth a checklist item in the user guide.

---

## 10. State Restoration — Not Covered by Any Source File (needs design)

None of the seven files address terminal/EA restarts. Open positions can be re-discovered on `OnInit()` via `PositionsTotal()`/magic-number filtering, but several pieces of **transient state cannot be reconstructed from positions alone** and will be lost on restart unless explicitly persisted:

- Whether the Dynamic Stop is currently armed (and its current trail level)
- Whether Partial Close has already been executed for a sequence
- Whether Recovery/Breakeven-buffer mode is currently active for a sequence
- Risk Reduction activation state
- The last processed candle time per timeframe (to avoid re-alerting/re-signaling on restart)
- Cumulative session profit (for the Session Profit Limit feature)

**Decided:** persist this small state block per `(Symbol, Magic Number)` in a JSON/CSV file under `MQL5/Files/`, updated on every state transition rather than on a timer. This same `(Symbol, Magic Number)` key also doubles as the collision check described in Q9.

---

## 11. Testing & Optimization Recommendations

- Because the strategy relies on multiple simultaneous positions, backtest with the **"Every tick based on real ticks"** model on a hedging-enabled test account — the default netting-style tester behavior will misrepresent sequence behavior.
- Use **Visual Mode** for initial validation, per the guide's own strong recommendation, with a chart template matching the EA's indicator settings exactly.
- Phase optimization rather than running all ~90 inputs at once:
  1. Indicator settings (QMP/BB/QQE periods) fixed at guide defaults first
  2. Position sizing / multiplier system
  3. Exit strategy + dynamic stop / partial close
  4. Risk controls (session, EOD/EOW, risk reduction) last
- Exclude cosmetic/display inputs, `InpMagicNumber`, and `InpUserComment` from any optimization pass.
- Match test account balance/leverage to the intended live account, as explicitly recommended in the guide.

---

## 12. Documentation Assets — What Exists vs. What's Missing

**Exists:** exhaustive end-user explanation of every input and every strategy concept (`EA_User_Guide.docx`), a shorter narrative walkthrough covering the same ground (`DCA_EA_Walkthrough.docx`).

**Missing (will need to be created during/after development):**
- A parameter-name-to-guide-section cross-reference (this report's §4 is a first pass at that)
- Developer-facing architecture notes (sequence data structure, state persistence format)
- A troubleshooting/FAQ section for common broker-side errors (margin, min stop distance, hedging not supported)
- Release notes / changelog conventions for future versions

---

## 13. Open Questions for Stakeholders

1. ~~**QMP Filter's own `HigherTimeFrame` input**~~ — **RESOLVED:** Purely a legacy/visual feature. The main EA leaves `HigherTimeFrame=0` when calling `iCustom("QMP Filter", ...)` and implements the Higher Timeframe Direction Filter as fully separate logic against BB/QQE.
2. ~~**`InpFibSequence=1`**~~ — **RESOLVED (final):** Kept the original name `InpFibSequence`, but retyped it as a **string** (default `"1,3,5,8,13"`) so it actually holds the Custom Multiplier String described in the guide. This gives the best of both: correct type/behavior *and* full `default.set` name-compatibility (the old numeric `1` is simply overwritten by the new default on import, which is harmless since it's only read when `InpMultiplierSystem` = Custom).
3. ~~**Trailing Stop naming**~~ — **RESOLVED:** `InpTrailingStepPips` = Trailing Distance (pips, how far behind price the stop sits); `InpTrailingStepBlockPips` = step-block granularity (minimum move before the stop re-adjusts). Confirmed as originally suspected. **Naming kept as-is** to match `default.set` exactly — no rename.
4. ~~**Partial Close percent**~~ — **RESOLVED:** Locked to a 2-value enum (`None` / `50%`), matching the guide's dropdown exactly. No free-form percentage input.
5. ~~**`BB.mq5`**~~ — **RESOLVED:** Native `iBands()` confirmed. `BB.mq5` is not used by the EA; the file remains in the project as reference only.
6. ~~**Applied-price / enum types**~~ — **RESOLVED:** `InpBBAppliedPrice`, `InpMAAppliedPrice`, and `InpMAMethod` (and all other dropdown-described fields — indicator mode, exit strategy, lot sizing mode, etc.) will be implemented as proper native enums (`ENUM_APPLIED_PRICE`, `ENUM_MA_METHOD`, and EA-defined custom enums where MQL5 has no built-in type) rather than raw integers.
7. ~~**Hedging account requirement**~~ — **RESOLVED:** No hard fail. The EA will check `ACCOUNT_MARGIN_MODE` at `OnInit()` and, if the account is netting rather than hedging, print/log a one-time warning (opposite-direction trades will net against each other instead of running as independent sequences) but will still initialize and run. Confirmed as intentionally different from the Q9 magic-number check — this one is a behavior trade-off the user can accept; a magic-number collision is a data-integrity risk and is not.
8. ~~**State persistence mechanism**~~ — **RESOLVED:** File-based, under `MQL5/Files/`, keyed by `(Symbol, MagicNumber)` — e.g. `DCA_EA_state_<symbol>_<magic>.json` (or CSV). Chosen for portability across terminal/VPS migrations and ease of manual inspection during troubleshooting.
9. ~~**Magic number scope**~~ — **RESOLVED:** One Magic Number per chart/symbol combination, enforced. `(Symbol, MagicNumber)` is the exclusive key for sequence tracking and the state file. At `OnInit()`, the EA will check for open positions or an existing state file matching this symbol under a *different* magic number pattern that suggests a conflicting instance, and — confirmed intentionally different from the Q7 hedging check — will hard-fail (`INIT_FAILED`) rather than warn-and-continue, since a magic-number collision would silently corrupt sequence tracking rather than just changing trading behavior.

---

## 14. Suggested Next Steps

1. ~~Confirm/resolve Q1–Q9 above.~~ **Done — all nine fully resolved, see §13.**
2. ~~Lock the exact `input` block.~~ **Done** — full input block, indicator handles, and `OnInit()` validation.
3. ~~Build the entry-signal pipeline and position sizing.~~ **Done** — new-bar detection, zone-breach tracking, QMP dot reading, sequence tracking, and lot sizing (Fixed, Step-Based, margin-based %Balance/%Equity).
4. ~~Build exit logic: all six Exit Strategies, Dynamic Stop, Partial Close, Risk Reduction.~~ **Done.** See prior entry for the design decisions made (Recovery Mode priority, Dynamic Stop not pausing entries, Partial Close pausing entries, per-bar/per-tick cadence split).
5. ~~Build remaining entry-side filters (Step 5) and state persistence (Step 6).~~ **Done, in one pass, un-validated against a reference implementation.** Notable points:
   - **All eight remaining entry gates are now wired in**: BB Width filter, Require Centre Band Cross Before New Sequence, No-Trigger-On-Centre-Band-Breach, re-entry-after-close (`InpRequireBBBandTouchForReentry` / `InpRequireQQEScenarioBForReentry` — this was the long-deferred TODO from earlier phases, now resolved), Minimum Signal Distance, MA Filter, Higher Timeframe Direction Filter, and All-Signals-Must-Match-Entry (including its lesser-known side effect of capping Max Sequences Per Direction at 1, per the guide's own advisory text).
   - **BB Width formula is an inference**, same category as the earlier %Balance/%Equity question but lower-stakes (affects filter selectivity, not position size): width expressed as a percentage of the middle band's price level. The guide gives no exact formula ("hard to eyeball... trial & error"), so this wasn't treated as a blocking question the way lot sizing was.
   - **Entry gates are split into two categories**: "new-sequence-only" (BB Width, Centre Cross, No-Trigger-On-Breach, MA Filter, HTF Direction — never checked for add-on trades or Recovery Mode entries) and "add-on-only" (Minimum Signal Distance — explicitly still applied even during Recovery Mode, since the guide frames Recovery Mode as bypassing the BB/QQE *zone* check specifically, not every independent risk control).
   - **State persistence** is plain delimited text under `MQL5/Files/`, one file per (Symbol, Magic Number), rewritten in full every tick rather than incrementally — simpler to reason about and more robust than a fine-grained dirty-flag across two dozen mutation points, at a small, inconsequential disk-I/O cost. Loaded in `OnInit()`, saved every tick and once more on `OnDeinit()`. Every loaded sequence is immediately re-synced against live positions in case anything changed while the EA was offline.
   - **A relocation was required, not just an addition**: `SyncSequenceFromLivePositions()` and `RemoveSequenceAt()` had to move earlier in the file (from the exit-logic section to right after the core sequence-tracking globals) since `LoadState()` — called from `OnInit()` — depends on them, and MQL5 requires define-before-use ordering in the same file.
   - **Explicitly not yet validated against the guide's full behavioral spec or a reference implementation** — the user has a working, compiled build running in Visual Mode, but cross-checking against `EA_User_Guide.docx` in detail, and against an existing reference EA the user has, is deferred to a combined validation pass after this step, per an explicit decision to prioritize completing the build first.
6. Still deferred: session/EOD/EOW gating (trading hours, day-of-week, End of Day/End of Week actions), Session Profit Limit, and the on-screen display (info panel and chart lines) — none of these were part of Steps 1–6.
7. **Next up: the combined validation pass.** Recommended approach — Visual Mode with the full indicator template loaded (per the guide's own method), plus a handful of targeted scenarios aimed at the specific assumptions documented above and in the exit-logic entry (Recovery Mode priority, Dynamic Stop entry-pausing, Partial Close trade selection, BB Width formula, Centre Band Cross semantics, HTF alignment), cross-checked against the user's reference EA where available.

## 15. Post-Build Incident: Performance Fix (State Persistence)

After Step 6 shipped, the EA exhibited severe slowness and freezing, most noticeable in Strategy Tester Visual Mode.

**Root cause**: `OnTick()` called `SaveState()` unconditionally on every tick, and `SaveState()` performs a full `FileOpen()` → write → `FileClose()` cycle each call — synchronous disk I/O on every single tick. This is a well-known MQL5 performance anti-pattern. It was introduced when Step 6 was built; the design rationale at the time explicitly (and incorrectly) called the per-tick cost "small, inconsequential" — that assessment was wrong and is corrected here.

**Fix applied**: replaced unconditional per-tick saving with a throttled + event-driven model:
- Routine saves in `OnTick()` go through `SaveStateThrottled()`, rate-limited to roughly once every 2 real seconds via `GetTickCount64()` (wall-clock time, unaffected by Strategy Tester's simulated time).
- Structural events that need immediate durability — a trade opening (`TryEnterSequence`), a sequence closing (`CloseSequenceAndCleanup`), and a partial close (`ExecutePartialClose`, both exit paths) — call `SaveState()` directly, bypassing the throttle, so nothing important is lost between throttle windows.
- `OnDeinit()` still saves unconditionally on shutdown, as before.

**Secondary hardening added at the same time**: `LoadState()`'s file-read loop is now bounded by a sane maximum line count (10,000), as a defensive measure against a corrupted or mid-write-interrupted state file causing `FileIsEnding()` to never trip — not the cause of this specific incident, but a reasonable precaution given a state file could plausibly have been left mid-write during the period of severe slowness.

**Verified**: file re-checked line-by-line for brace/paren/bracket balance, global-variable-before-declaration, and function-called-before-defined — all clean.
5. Ready to start drafting the EA's `input` block and the `OnInit()` validation logic (hedging warning, magic-number collision check, exit-strategy/indicator-mode compatibility) as the first concrete code artifact whenever you'd like to proceed.
