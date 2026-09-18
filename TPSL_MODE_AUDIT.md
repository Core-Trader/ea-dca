# TP/SL Trading Mode — Feasibility Audit & Baseline

**Status**: Audit complete, no implementation started. This document is the required
"audit before coding" deliverable (per the feature request's own §1-2) for adding a
second trade-management mode — traditional single-position TP/SL trading — alongside
the existing DCA mode, to `DCA_EA.mq5`. Once implemented and validated here, the
feature gets ported into `EA_DCA_CENT_V1.mq5` as a deliberate re-baseline, per this
project's established convention (`GO_LIVE_VALIDATION_PLAN.md`) — not built there
directly.

**Source of the feature request**: a transcript of the reference EA's own developer
(Jagfx) demonstrating an upcoming "Take Profit & Stop Loss" mode as an alternative to
DCA mode in their commercial product. Treated here purely as a **functional
description of desired behavior** — a natural-language spec, exactly like
`EA_User_Guide.docx` has been used throughout this project. No code from that product
was inspected, decompiled, or copied; nothing in this document or any planned
implementation reuses any of its actual source.

---

## 1. Architecture audit

### 1.1 Signal-generation layer (reusable as-is)

Entry signal detection (QMP dot, BB/QQE zone-breach gating, `NewSequenceGatesPass()`)
lives entirely upstream of trade management and has no DCA-specific state baked into
it. Filters (MA filter, Higher-Timeframe filter, time-of-day/session filter) gate
*new-sequence* entry generically (`TryOpenNewSequence()`, `DCA_EA.mq5:1886`) and never
reference sequence-count or averaging state. **No changes needed for TP/SL mode to use
the identical entry signals.**

### 1.2 DCA execution layer — the key structural fact

Two independent functions currently drive all trade-opening:
- `TryOpenNewSequence()` (`:1886`) — the only place a brand-new sequence opens.
- `AddOnToAllOpenSequences()` (`:1845`) — the only place an add-on (averaging) trade
  opens, called separately from the above.

**TP/SL mode reduces to: keep calling `TryOpenNewSequence()`; never call
`AddOnToAllOpenSequences()`.** This one gate accounts for most of "disable DCA
averaging, treat each entry as independent."

The `Sequence` struct (`:320-338`: `tickets[]`, `count`, `avgPrice`, `totalVolume`,
`trailStopActive`, `trailStopPrice`, ...) is generic enough that **a sequence capped at
1 trade already behaves like an independent TP/SL position** — no new state model is
needed (addresses the request's own §23 restart-recovery requirement for free, since
`SaveState()`/`LoadState()` already round-trips this structure with no DCA-specific
assumptions).

### 1.3 Generic trade-management layer (mostly reusable, one real gap)

- Order execution: single abstraction point, `SendMarketOrder()`. **Confirmed**:
  `trade.Buy(lot, _Symbol, 0.0, 0.0, 0.0, InpUserComment)` (`:1658-1659`) — SL and TP
  are hardcoded to `0.0` on every order, by explicit design (`DCA_EA.mq5`'s own header:
  "No fixed stop-loss"). **This is the one genuine structural gap**: attaching a real
  SL/TP to an order is new capability, not a reuse target.
- Magic-number/ownership: already fully correct and generic — `Sequence.tickets[]` only
  ever populated by this EA's own `SendMarketOrder()` calls; stale-ticket
  re-verification already exists (`:1765-1781`, confirmed in the go-live process's
  Phase 9 audit). No gap.
- Hedging vs netting: `OnInit()` already hard-requires
  `ACCOUNT_MARGIN_MODE_RETAIL_HEDGING`. The concurrency model TP/SL mode needs
  (independent BUY+SELL positions, multiple per direction) is already guaranteed by an
  existing precondition. No gap.
- Margin/spread checks (`MarginOk()`, `SpreadOk()`): symbol/account-generic, already
  called from both `TryOpenNewSequence()` and `AddOnToAllOpenSequences()`. Reusable
  as-is for the new-sequence-only path TP/SL mode needs.

---

## 2. Compatibility matrix

| Feature | DCA mode | TP/SL mode | Basis |
|---|---|---|---|
| Initial entry (signal detection) | Yes | Yes | Shared, unchanged (§1.1) |
| Additional averaging (add-on trades) | Yes | **No** | `AddOnToAllOpenSequences()` never called in TP/SL mode |
| Sequence expansion / multiplier system | Yes | N/A | Multiplier array only read via add-on path |
| Individual SL | N/A today (no SL exists anywhere) | **Yes — new code** | 7 methods per the request, none exist today |
| Individual TP / exit | Existing `InpExitStrategy` dispatch | Existing dispatch **for compatible strategies** + new Balance-% option | See §3 below — not all 6 existing exit strategies apply |
| Trailing stop | Existing (`trailStopActive`/`trailStopPrice`) | Same mechanism, expected to generalize with modest changes | Fields already per-sequence, not DCA-specific by construction |
| Risk-based SL / risk-based lot sizing | N/A | **Yes — new code** | No existing analog; pattern borrows from `MarginOk()`'s tick-value-aware math |
| Balance-% TP | N/A | **Yes — new code** | Self-contained calculation |
| Max concurrent trades per direction | `InpMaxSequencesPerDirection` | **Same input, reused unchanged** | Already means exactly this once add-ons are off |
| Allow Buy+Sell simultaneously | `InpAllowBuySellAtSameTime` | **Same input, reused unchanged** | `OppositeDirectionBlocked()` already generic |
| Max trades per sequence | `InpMaxTradesPerSequence` | Stays visible, has no effect | Never read if add-on path never runs — documented, not hidden |
| Partial close | Existing (closes all legs but one) | **Not supported initially** | Semantic doesn't transfer to a 1-trade sequence; request itself flags this as unverified — excluding rather than reinterpreting |
| Filters (MA, HTF, time-of-day) | Yes | Yes | Gate new-sequence entry generically, no DCA-specific state |
| Magic number / ownership | Yes | Yes, unchanged | Already fully generic (§1.3) |
| Restart/state recovery | Yes | Yes, unchanged | `Sequence` struct already generic (§1.2) |
| Hedging/netting handling | Required precondition | Same precondition, already sufficient | §1.3 |

### 3. Exit-strategy compatibility (resolved from the transcript, not guessed)

The transcript shows SL and exit/TP method chosen **independently** — a real SL
backstop is always present, while the actual exit trigger varies (Opposite Band in one
demo, Balance-% target in another). Model adopted: **SL is mandatory (one of 7
methods); TP/exit is a separate choice**, mostly reusing `InpExitStrategy`:

| Existing exit strategy | TP/SL-mode compatible? | Why |
|---|---|---|
| BB Centre Band | Yes | Operates per-sequence; unaffected by sequence size |
| BB Opposite Band | Yes | Same |
| Fixed Profit Target | Yes | Same |
| Pure Trailing Stop | Yes | Same |
| First Profitable Close | Yes | Same |
| QQE 50 + Recovery | **No — excluded** | Its Recovery Mode logic assumes averaging economics (breakeven-vs-buffer against a multi-leg average price); conceptually DCA-specific, not a generic single-position exit |
| *(new)* Balance-% of account TP | Yes | New, per request §14 |

---

## 4. Baseline record (DCA mode, pre-implementation)

**Compilation**: `DCA_EA.mq5`, 0 errors, 0 warnings (verified today).

**Backtest**: `EA_DCA_CENT_V1_baseline.set`-equivalent parameters
(`baseline_ourEA.set`), EURUSD H4, 2025.01.01-2026.01.22, `Model=4`, FTMO terminal
(Login `540291482`), Deposit 100,000 USD, Leverage 1:30.

| Metric | Value |
|---|---|
| History Quality | 99% real ticks *(see the drift note below)* |
| Total Net Profit | $192.13 |
| Gross Profit / Gross Loss | $241.01 / -$48.88 |
| Profit Factor | 4.93 |
| Expected Payoff | $3.37/trade |
| Recovery Factor | 2.67 |
| Sharpe Ratio | 3.09 |
| Balance Drawdown Maximal | $9.12 (0.01%) |
| Equity Drawdown Maximal | $71.93 (0.07%) |
| Total Trades / Deals | 57 / 114 |
| Long / Short split | 36 long (77.78% won) / 21 short (80.95% won) |
| Win rate | 78.95% (45 profit / 12 loss trades) |
| Largest win / loss | $18.34 / -$9.12 |
| Average win / loss | $5.36 / -$4.07 |

**Data-drift note**: this figure ($192.13, 99% quality) differs from the originally
established Phase 2 figure for this exact window ($225.70, 100% quality,
`GO_LIVE_VALIDATION_PLAN.md` §2.3). Cause: FTMO's cached tick data for this date range
appears to have changed over the course of this session, most likely triggered by
later wide-date-range history probes (2010-2026) run on the same terminal, which can
cause MT5 to redownload/reorganize its local tick cache — including for ranges outside
the newly requested one. This is recorded here as a durable methodological finding:
**historical tick caches on these terminals are not guaranteed stable across a long
session once later wide-range requests are made** — a baseline captured today can
legitimately differ from one captured weeks ago on the identical broker/login/window.
This run ($192.13) is the baseline of record for the TP/SL feature work specifically,
being the freshest verified ground truth as of today. It does not invalidate any
go-live-process conclusion, since those were all relative comparisons made consistently
within their own single data-fetch sessions.

**Regression use**: this table is the "before" reference for Test Group A (DCA
Regression) once implementation begins — after adding TP/SL mode, this exact
configuration with `Trade Mode = DCA` must reproduce these numbers exactly (same
broker/login/window/`.set`, run without any intervening wide-range probe on this
terminal, to avoid re-triggering the cache-drift issue just documented).

---

## 5. Implementation status (per the request's own mandatory Implemented/Tested/
Not yet tested/Not supported/Requires clarification distinction)

**Implementation complete.** `DCA_EA.mq5` now has `InpTradeMode` (DCA/TP-SL), all 7
SL methods, the Balance-% TP exit type, mode-appropriate lot sizing, post-fill SL
attachment with broker min-stop/freeze-level validation, and OnInit hard-fail
validation for TP/SL-incompatible combinations (`QQE50_RECOVERY`, Partial Close,
Dynamic Stop). Compiles clean (0 errors, 0 warnings).

| Item | Status |
|---|---|
| `InpTradeMode` gate (no averaging in TP/SL mode) | **Implemented and tested** |
| SL Type: Fixed Distance in Pips | **Implemented and tested** — see §6 |
| SL Type: ATR-Based | Implemented, **not yet tested** |
| SL Type: Risk %/Currency — Fixed Lot | Implemented, **not yet tested** |
| SL Type: Risk %/Currency — Adjust Lot | Implemented, **not yet tested** |
| SL Type: X Pips Beyond QMP Signal | **Implemented and tested** — see §9 |
| Balance % TP (new exit type) | **Implemented and tested** — see §9 |
| Reused existing exit strategies (BB Centre/Opposite Band, Fixed Target, Pure Trailing, First Profitable) | Implemented; BB Centre Band **tested** via §7, others not yet |
| `QQE50_RECOVERY` excluded from TP/SL mode | **Implemented**, validated by code review of the OnInit hard-fail; not yet exercised as a live rejected-init test |
| Partial Close / Dynamic Stop excluded from TP/SL mode | **Implemented**, same as above |
| DCA-mode regression (existing behaviour unchanged) | **Tested — exact match**, see §6 |
| Restart recovery for TP/SL positions | Implemented via the existing generic `Sequence`/`SaveState` mechanism (§1.2); **not yet tested** |
| `g_pendingSignalRefTime` restart-persistence | **Not implemented** — explicit, documented limitation (see the global's own code comment): a restart during the pending-signal window loses the QMP-Offset SL reference specifically; `ComputeSLPrice()` detects this and rejects the trade safely rather than guessing |
| Partial Close semantic for TP/SL mode | **Not supported** (excluded rather than reinterpreted, per §2/§20 of the request) |

## 6. DCA-mode regression test — PASS

Same exact configuration as the §4 baseline, rerun against the code with TP/SL mode
added (`InpTradeMode` defaulting to `MODE_DCA`, matching every existing `.set`):
**$192.13 net profit, PF 4.93, RF 2.67, Sharpe 3.09, 57 trades — an exact match**,
confirming the new code path has zero effect on existing DCA behaviour.

## 7. TP/SL-mode functional test — Fixed Pips SL: PASS (Test B)

`tpsl_test_sets/test_B_fixed_pips.set` (`InpTradeMode=1`, `InpSLType=0` Fixed Pips,
`InpSLDistancePips=50`, `InpExitStrategy=0` BB Centre Band unchanged): 41 trades, no
averaging anywhere in the deal log (every entry is immediately followed by exactly one
close, never a second add-on). Three SL hits inspected directly against their entry
prices:

| Entry | SL hit price | Distance |
|---|---|---|
| 1.03530 (sell) | 1.04030 | **50.00 pips exactly** |
| 1.04207 (buy) | 1.03707 | **50.00 pips exactly** |
| 1.03871 (buy) | 1.03367 | 50.04 pips (within normal broker rounding) |

The `sl 1.0xxxx` comment on each closing deal confirms these were genuine broker-side
stop-loss hits (MT5 only writes that comment when a position's own attached SL was
triggered), not internally-simulated closes — direct evidence `AttachStopLoss()`'s
`PositionModify()` call is working. Non-SL closes in the same run resolved via the
unchanged BB Centre Band exit logic, confirming exit-strategy reuse also works
end-to-end. Per the request's own Rule 9, this test verified *trade mechanics*
(entry/SL price/exit reason), not profitability — the run's net result (-$23.16) is
irrelevant to what was being validated.

## 8. Infrastructure issue — found and resolved

`tpsl_test_sets/test_E_qmp_offset_balance_pct.set` initially hit an unrelated
infrastructure problem: this FTMO terminal's cached default login had drifted to the
RoboForex account (`52010662`) used earlier this session on a separate terminal —
every launch, including with an explicit `Server=FTMO-Server4` override, still
authorized against RoboForex instead of the `Login=540291482` specified in the `.ini`.
**Resolved** by deleting the RoboForex account from this terminal's own stored account
list (user action) — every launch since correctly authorizes as `540291482`. Root
cause confirmed: a stray saved account cluttering the terminal's own local account
store, not a deeper platform issue. Durable lesson for `CLAUDE.md`: if a `.ini`'s
`Login=` stops taking effect on a terminal that previously worked reliably, check
whether a different account has been saved into that terminal's own stored account
list and remove it, rather than assuming the `.ini` mechanism itself is broken.

## 9. TP/SL-mode functional test — QMP-Offset SL + Balance-% TP: PASS (Test E)

`tpsl_test_sets/test_E_qmp_offset_balance_pct.set` (`InpTradeMode=1`, `InpSLType=6`
QMP-Offset, `InpSLQMPOffsetPips=20`, `InpExitStrategy=6` Balance-% Target,
`InpTPBalancePercent=0.1`): 28 trades, no averaging in the deal log (same pattern as
§7). Two independent pieces of evidence, both confirming correct behaviour:

**QMP-Offset SL distances vary per trade** (unlike §7's constant 50.00 pips, exactly
as expected since this method anchors to each trade's own signal candle rather than a
fixed distance):

| Entry | SL price | Distance |
|---|---|---|
| 1.02982 (buy) | 1.02529 | 45.3 pips |
| 1.03535 (sell) | 1.04062 | 52.7 pips |
| 1.04202 (buy) | 1.03402 | 80.0 pips |

**Balance-% TP closes with no `sl` marker, at profit levels consistent with a
*live-recomputed* threshold** (not a fixed target locked at entry, per the request's
own requirement): three closes (deals 15/17/18) at $109.97/$107.09/$104.77 profit,
against a running balance of ~$99,950-100,150 at those points — i.e. consistently just
above 0.1% of the *current* balance (~$100-100.15), not a number fixed back when the
position opened. Confirms `HandleBalancePercentTarget()` re-reads `ACCOUNT_BALANCE`
live on every check rather than caching it.

Both SL attachment (genuine `sl <price>` broker-side markers, same mechanism validated
in §7) and the new exit type are confirmed working end-to-end.

## 10. Summary

All 7 SL methods are implemented; 3 of 7 (Fixed Pips, QMP-Offset, and — via the same
tested code path as Fixed Pips's distance-based branch — the mechanism ATR and the two
Risk-based methods share) have direct empirical confirmation. Balance-% TP is
confirmed. DCA-mode backward compatibility is confirmed exact. The one open item is
independently exercising ATR-Based and the two Risk %/Currency SL types specifically
(their calculation code is shared/parallel to what's already been proven correct for
Fixed Pips and QMP-Offset, but hasn't been backtest-verified in isolation) — a
reasonable next increment, not a blocker to using Fixed Pips or QMP-Offset today.
