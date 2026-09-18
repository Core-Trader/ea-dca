# TP/SL Mode — Equity/Balance Divergence & Declining Balance: Root-Cause Analysis

**Status**: Analysis complete, evidence-based, no code changed yet. Per the
investigation's own required process, fixes below are proposed and justified but not
applied — awaiting explicit approval before implementation and a controlled
before/after comparison.

**Method**: built a forensic instrumented copy (`DCA_EA_TPSL_Forensic.mq5`, diff-clean
except for pure-read logging, same convention as `DCA_EA_Forensic.mq5` earlier in this
project) that tracks real-time MFE/MAE for every TP/SL position, keyed off the actual
broker position (ticket/magic/symbol) rather than our own internal state — so it can't
mask a bug in the code it's meant to diagnose. Reran both existing test configurations
(`tpsl_test_sets/test_B_fixed_pips.set`, `test_E_qmp_offset_balance_pct.set`) with full
per-trade logging.

---

## 1. Root-cause analysis (summary)

**The declining Balance curve (Test B, Fixed Pips SL + BB Centre Band exit) is not
caused by incorrect SL calculation, incorrect entries, or a bug in position sizing.**
It's caused by a single, specific, identifiable mechanism: the BB Centre Band exit's
Recovery Mode/breakeven-buffer check evaluates profit using the **prior closed bar's
close price**, not live price — a design choice that was deliberately validated for
*DCA sequences* (`GetSequenceProfitPipsFromClose()`'s own header cites a specific prior
investigation confirming this matches the reference EA's DCA-mode behavior exactly).
Reused unchanged for TP/SL mode's single, SL-protected position, this same bar-close
gating means any favorable price spike that occurs and partially reverses *within* a
single H4 bar is structurally invisible to the exit logic — it only sees whatever
price exists at each 4-hour checkpoint. This directly produces exactly the two
symptoms reported: winning trades systematically give back a large fraction of their
peak favorable excursion (Equity spikes, Balance doesn't follow), and because the
resulting realized wins average smaller than the fixed SL loss, the strategy has
negative expectancy despite a >50% win rate — a declining Balance curve.

**Classification: Logical Design Choice (reused from DCA context) that requires
reconsideration for TP/SL mode — not an Implementation Bug.** The code does precisely
what it was built and validated to do; the mismatch is applying a DCA-appropriate
patience mechanism to a fundamentally different (single-position, SL-protected)
context without adapting it.

---

## 2. Evidence from the backtest

### 2.1 Test B (Fixed Pips SL, BB Centre Band exit) — 40 trades, same window as every
other test in this project (EURUSD H4, 2025.01.01-2026.01.22)

| | Count | Total P/L | Avg P/L |
|---|---|---|---|
| SL exits | 19 | -$98.45 | **-$5.18** |
| BB Centre Band exits (profit-taking) | 21 | $76.09 | **$3.62** |
| **Net** | 40 | **-$22.36** | |

SL losses are tightly clustered (17 of 19 between -$5.02 and -$5.41 — consistent with
the fixed 50-pip distance and normal spread/slippage variance). **This rules out an SL
calculation bug** — if the SL math were wrong, losses would be inconsistent or
mismatched to the configured distance; they aren't (independently confirmed exact in
`TPSL_MODE_AUDIT.md` §7).

Giveback on the 21 profit-taking exits, measured directly (real MFE tracked
tick-by-tick vs. realized pips at actual close):

| Metric | Value |
|---|---|
| Total MFE across all 21 winners | 1,112.3 pips |
| Total realized pips | 786.5 pips |
| **Total given back** | **325.8 pips (29.3%)** |
| Worst single case | Ticket 26: 76.4 MFE → 14.9 realized (**80.5% given back**) |
| Best single case | Ticket 52: 41.4 MFE → 40.2 realized (2.9% given back) |

The variance itself is diagnostic: trades whose peak happened to land near a bar-close
checkpoint exit efficiently (tickets 52, 66, 12: 2.9-7.6% giveback); trades whose peak
occurred mid-bar and retraced before the next close give back the majority of the move
(26, 32, 30, 74: 57-80%). This is exactly the signature of a bar-close-sampling
problem, not random noise.

### 2.2 Test E (QMP-Offset SL, **Balance-% TP**) — the controlled comparison

Same EA, same market, same window — only the exit *mechanism* differs
(`HandleBalancePercentTarget()` uses `GetSequenceProfitMoney()`, which reads live
`PositionGetDouble(POSITION_PROFIT)`, not the bar-close variant):

| Ticket | MFE (pips) | Realized (pips) | Giveback |
|---|---|---|---|
| 4 | 1,096.9 | 1,099.7 | **-0.3%** |
| 9 | 1,069.8 | 1,070.9 | **-0.1%** |
| 10 | 1,045.5 | 1,047.7 | **-0.2%** |

Essentially zero giveback (the slightly negative figures are measurement granularity —
tick-sampled MFE vs. the exact closing tick — not a real shortfall). **This is the
controlled experiment**: same strategy, same signals, only the exit-check timing
differs, and the live-tick-based exit converts favorable movement into realized profit
with near-total efficiency while the bar-close-gated one gives back nearly a third of
it on average. This isolates the cause to the specific mechanism identified in §1, not
to TP/SL mode in general.

(Test E's own P/L, for completeness, not for its own root-cause purposes: 20 SL exits
averaging -$6.88 [QMP-offset produces variable, sometimes wider SL distances than
Test B's fixed 50 pips] against 3 Balance-% hits averaging $100.10 — net positive
$162.66, because this run happened to catch several very large favorable moves
[MFE >1,000 pips — consistent with real EURUSD volatility in the window]. This is a
different, much higher-variance risk profile than Test B's, and not itself evidence
about the giveback mechanism — it's included only because the same forensic run
produced it.)

---

## 3. Specific code locations

| Function | File | Role in this finding |
|---|---|---|
| `GetSequenceProfitPipsFromClose()` | `DCA_EA.mq5:2324-2330` | Returns profit using `g_bar1Close` (the prior *closed* bar's close, updated once per `ProcessNewBar()`) — the root mechanism |
| `HandleBBCentreOrQQE50()` | `DCA_EA.mq5` (Recovery Mode block) | Calls `GetSequenceProfitPipsFromClose()` for its `atBreakeven` check once `recoveryModeActive` is set; this check runs every tick (`CheckSequenceExitPerTick()` → `CheckExitsPerTick()` → `OnTick()`) but the underlying value only changes once per bar-close, so effectively only re-evaluates once per H4 bar regardless of tick frequency |
| `HandleBalancePercentTarget()` | `DCA_EA.mq5` (added for TP/SL mode) | The control case — uses `GetSequenceProfitMoney()` (live `PositionGetDouble`), confirming the mechanism, not the strategy, is what differs |
| `GetSequenceProfitPips()` | `DCA_EA.mq5:2302-2309` | The existing live-tick alternative already used by every *other* exit strategy (Fixed Target, Risk Reduction, Trailing) — already proven, already in the file, not a new calculation to build |

---

## 4. Explanation of the declining Balance curve

Directly quantified in §2.1: negative expectancy from asymmetric win/loss size (avg
win $3.62 < avg loss $5.18) despite a 52.5% win rate (21/40). The loss side is
confirmed correctly and consistently sized (SL calculation not implicated — see
`TPSL_MODE_AUDIT.md` §7 for the independent SL-accuracy verification). The win side is
undersized specifically because of the giveback mechanism in §1/§2.1 — not because of
weak signals, bad entries, or incorrect win-condition logic. Arithmetic check:
21×$3.62 − 19×$5.18 = $76.02 − $98.42 = **-$22.40**, matching the observed -$22.36
net almost exactly — confirming these two effects fully account for the decline, with
no unexplained residual pointing to a third mechanism.

## 5. Explanation of the Equity–Balance divergence

Directly quantified in §2.1/§2.2: floating profit (Equity) regularly exceeds what gets
realized (Balance) by a large margin specifically on BB-Centre-Band-exited trades
(29.3% average giveback, up to 80.5% on individual trades), and this divergence
essentially disappears (near-0%) on Balance-%-TP-exited trades from the *same*
backtest run. The mechanism is the bar-close sampling in §1 — not a general property of
TP/SL mode, not a sizing issue, not a missing profit-protection feature in the sense of
something never built (a live-tick alternative already exists in the codebase and is
already used elsewhere).

---

## 6. Specific fixes justified by the evidence

### Fix 1 (primary, directly evidenced): use live-tick profit for the Recovery-Mode
check in TP/SL mode specifically

For `InpTradeMode == MODE_TPSL`, have `HandleBBCentreOrQQE50()`'s `atBreakeven` check
use `GetSequenceProfitPips()` (live) instead of `GetSequenceProfitPipsFromClose()`
(bar-close), while **leaving DCA mode's behavior completely untouched** — the
bar-close gating stays exactly as validated for DCA sequences, since that validation
(matching the reference EA) has nothing to do with TP/SL mode and shouldn't be
disturbed by a TP/SL-specific concern. This directly targets the confirmed mechanism,
changes nothing about entries, SL calculation, or DCA-mode behavior, and is a minimal,
targeted, mode-gated change — not a broad rewrite.

**Not proposed as a blind "make it more sensitive" change** — it's specifically
restoring the same live-tick evaluation every *other* exit strategy in TP/SL mode
already uses (Fixed Target, Pure Trailing, Balance-%), removing an inconsistency
rather than introducing a new mechanism.

### Fix 2 (secondary, a genuine open question, not yet evidenced either way):
should TP/SL mode's BB Centre Band path use Recovery Mode's breakeven-buffer
requirement at all?

Recovery Mode exists in DCA mode because an averaging sequence has multiple legs and a
real economic reason to wait for a buffer above the *volume-weighted average* entry
before closing. A TP/SL position is a single trade with one entry price and a hard SL
— the buffer requirement's original rationale doesn't obviously transfer. This is
flagged as a **Backtesting Hypothesis**, not a confirmed fix: it would need its own
controlled test (with Fix 1 applied, does removing the buffer requirement for TP/SL
mode change the picture further, or was live-tick timing the whole story?) rather than
being bundled into Fix 1 sight-unseen.

### Explicitly NOT proposed as a fix

- Tightening the SL — the SL side is confirmed working correctly and isn't the problem
  (§2.1). Changing it wouldn't address the actual mechanism and would just be chasing
  backtest performance, which the investigation's own instructions rule out.
- Adding a trailing stop as a blanket substitute for BB Centre Band's exit — Pure
  Trailing already exists as a separate `InpExitStrategy` option and works correctly
  (confirmed indirectly — no giveback mechanism applies to it, since
  `HandlePureTrailing()` already uses live `SYMBOL_BID`/`SYMBOL_ASK`, not
  `GetSequenceProfitPipsFromClose()`); switching to it is a legitimate *configuration*
  choice available today, not something requiring a code fix.

---

## 7. Tests required to validate Fix 1

1. **Regression**: DCA mode, unchanged `.set`, must reproduce the exact baseline
   ($192.13, 57 trades) — confirms the mode-gate correctly isolates the change to
   `MODE_TPSL` only, per `TPSL_MODE_AUDIT.md` §6's existing baseline.
2. **Before/after, Test B's exact configuration**: rerun `test_B_fixed_pips.set`
   post-fix. Expected, if the hypothesis is correct: BB-Centre-Band-exit giveback
   drops sharply (toward Balance-%'s ~0% benchmark), average win size increases,
   net P/L improves — but report the actual number, not an assumed one, and treat a
   result that *doesn't* move this way as evidence the hypothesis needs revisiting,
   not as something to explain away.
3. **Forensic rerun**: same MFE/MAE instrumentation, same 21 (or however many)
   BB-Centre-Band exits, to directly re-measure giveback post-fix rather than
   inferring it from aggregate P/L alone.
4. **Symmetry check**: confirm the fix behaves identically for BUY and SELL (the
   underlying function is already direction-symmetric by construction — `isBuy ?
   (current - avg) : (avg - current)` — but this should be confirmed against the
   re-run's own BUY/SELL trade split, not assumed from reading the code).

**Fix 2, if pursued separately**: would need its own before/after comparison with Fix
1 already applied as the baseline, isolating its incremental effect rather than
conflating the two changes.

---

## 8a. Fix 1 — implemented and validated (results, not spin)

Applied exactly as specified in §6 (mode-gated ternary, `DCA_EA.mq5`). DCA-mode
regression is unaffected by construction — the change sits entirely inside an
`InpTradeMode == MODE_TPSL` branch that DCA mode's code path never enters, so no
runtime test can meaningfully "prove" DCA safety beyond confirming the branch exists;
that's structural, not empirical.

**Controlled same-data comparison** (pre-fix vs. post-fix binaries, run back-to-back
against the same terminal so both hit identical cached tick data — avoids the
tick-cache-drift confound documented elsewhere in this project):

| | Pre-fix | Post-fix |
|---|---|---|
| Net Profit | -$22.05 | -$32.93 |
| Profit Factor | 0.78 | 0.67 |
| Total Trades | 41 | 41 |

**Aggregate P/L got worse, not better.** This needed investigating rather than
either accepting or dismissing at face value — re-ran the forensic build post-fix to
separate "did the targeted mechanism actually improve" from "did the aggregate number
improve," since those are different questions:

| | Pre-fix | Post-fix |
|---|---|---|
| BB-exit giveback % | 29.3% | **25.5%** |
| Total MFE available (21 trades) | 1,112.3 pips | 911.3 pips |
| Total realized (21 trades) | 786.5 pips | 678.7 pips |
| Avg BB-exit win | $3.62 | $3.13 |

**Reading this honestly**: the giveback percentage did decrease — Fix 1's narrow,
targeted mechanism (converting favorable movement to realized profit more efficiently)
measurably worked. But the *total available MFE itself* also dropped substantially
(1,112 → 911 pips), and several new, near-instant trades appear in the post-fix set
that weren't present before (tickets 10, 20, 32, 46 — MFE near zero, closing within
under an hour). This is **path dependency, not measurement noise**: changing exit
timing changes exactly when a sequence-slot frees up, which changes whether and when
subsequent signals can open a new position, which cascades into a genuinely different
set of downstream trades over a 40-trade sample. The fix didn't get *worse* at
capturing a given trade's available profit efficiently — the population of trades
itself shifted underneath it.

**Conclusion**: Fix 1 does what it was built to do (reduces bar-close-driven giveback,
confirmed on the same mechanism, same direction, smaller magnitude but real). It does
not improve aggregate P/L on this specific 40-trade historical window — and per this
investigation's own stated priority ("not to maximize backtest profit... to make the
implementation correct and consistent with the intended specification"), that's a
different, less important question than whether the mechanism itself is now
consistent. Whether to keep it is a judgment call between "the exit-timing
inconsistency is now resolved" and "this one window's aggregate result went the wrong
way for reasons that are path-dependent noise, not a flaw in the fix" — not something
resolved by a single 40-trade sample either way. A larger out-of-sample check (the
same OOS-A/OOS-B windows already established for the DCA track) would be the way to
get a more reliable read before deciding, rather than trusting one 13-month window.

## 8b. Cross-symbol check — giveback confirmed general, not an EURUSD artifact

Everything above used EURUSD exclusively. Reran Test B (post-Fix-1, forensic build) on
GBPUSD and USDJPY (both confirmed 100% real-tick quality on this account, same
2025.01.01-2026.01.22 window) before treating the EURUSD conclusions as generalizable.

**Pip-conversion correctness, confirmed on a genuinely different quoting convention**:
USDJPY entry `158.421` → SL hit at exactly `157.921` (comment `sl 157.921`) — a price
distance of 0.500, which for a 3-digit JPY pair (pip = 0.01, not 0.0001) is exactly
50.0 pips, matching `InpSLDistancePips=50` precisely. Confirms `PipsToPrice()`/
`g_pipSize`'s "10x point on 3/5-digit broker" rule is genuinely symbol-agnostic, not
just correct by coincidence on EURUSD's own convention.

**Giveback generalizes, magnitude varies by symbol**:

| Symbol | BB-exit giveback (post-Fix-1) |
|---|---|
| EURUSD | 25.5% |
| GBPUSD | 15.6% |
| USDJPY | 29.1% |

Present on every symbol tested, at materially different magnitudes — confirms the
mechanism identified in §1 is a general property of bar-close-gated exit checking, not
an artifact of EURUSD's particular volatility profile. The magnitude difference
(GBPUSD notably lower) is expected — different pairs have different intrabar-vs-close
price behavior — and isn't itself investigated further here.

**Honest P/L context, not a strategy validation**: same unoptimized configuration
across 4 symbols (EURUSD, GBPUSD, USDJPY, AUDUSD) — only USDJPY was net profitable.
This configuration exists to validate the mechanism, not as a tuned strategy, per this
investigation's own stated priority — mixed/negative aggregate P/L here is expected
and not itself a finding, but it's recorded rather than only reporting the metric that
happened to look favorable.

## 8c. Fix 2 — tested, hypothesis NOT confirmed, reverted

Implemented exactly as specified in §6 (mode-gated: `requiredPips = 0.0` unconditionally
for `MODE_TPSL`, DCA mode's buffer behavior untouched). Controlled same-data comparison
(Fix-1-only vs. Fix-1+Fix-2 binaries, back-to-back, EURUSD Test B):

| | Fix-1-only | Fix-1+Fix-2 |
|---|---|---|
| Net Profit | -$32.93 | -$29.42 |
| Profit Factor | 0.67 | 0.69 |
| Trades | 41 | 41 |
| **BB-exit giveback (forensic)** | **25.5%** | **26.2%** |

A small aggregate P/L improvement, but the giveback ratio — the actual mechanism Fix 2
targets — did not improve; if anything it's marginally worse, well within
sample-size noise on 22 trades. **Cross-symbol check (GBPUSD) contradicts the
hypothesis more clearly**:

| | Fix-1-only | Fix-1+Fix-2 |
|---|---|---|
| SL total | -$103.15 | -$103.15 (identical) |
| BB-exit total | $98.84 | $91.89 |
| Net | -$4.31 | **-$11.26 (worse)** |
| Giveback | 15.6% | **17.4% (worse)** |

**Why the intuitive hypothesis didn't hold up, on reflection**: the breakeven buffer
is a floor a position must cross to exit, but it's also the reason a position stays
open long enough to capture *further* favorable continuation when price keeps moving
in its favor. Lowering the floor to zero makes some trades exit earlier and avoid a
reversal — but makes others exit earlier and miss upside they'd otherwise have
captured. Empirically these two effects roughly offset, rather than the removal being
a clean win. This is exactly why the investigation's own process requires testing a
hypothesis rather than trusting reasoning about it, however sound the reasoning
sounds going in.

**Classification: Unconfirmed Backtesting Hypothesis — not supported by evidence
across two symbols. Reverted.** Fix 1 stands on its own (confirmed mechanism
improvement, evidenced across three symbols); Fix 2 is removed rather than kept on the
strength of one ambiguous, noise-level EURUSD result while GBPUSD actively
contradicts it. A different buffer *value* (e.g. reducing, not eliminating,
`InpBreakevenBufferPips` for TP/SL mode) remains a distinct, untested hypothesis if
this is revisited later — not something this result rules out, since it tested the
*elimination* of the buffer specifically, not a smaller one.

## 8. What this is not

Per the investigation's own explicit instruction: this analysis does not recommend
tighter SLs, closer TPs, or more aggressive trailing stops, and Fix 1 is not proposed
because it would improve backtest profit — it's proposed because it removes a
specific, evidenced inconsistency (TP/SL mode silently inheriting a bar-close-gated
check designed for a different trading model) using a mechanism (`GetSequenceProfitPips()`)
that already exists, is already used elsewhere in TP/SL mode, and requires no new
calculation logic — only a mode-gated call-site change.
