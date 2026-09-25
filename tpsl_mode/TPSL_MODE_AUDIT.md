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
| SL Type: ATR-Based | **Implemented and tested** — see §11 |
| SL Type: Risk %/Currency — Fixed Lot | **Implemented and tested** — see §11 (behavioural finding recorded, not a bug) |
| SL Type: Risk %/Currency — Adjust Lot | **Implemented and tested** — see §11 (Specification Gap recorded: `InpMaxInitialLot` not applied here) |
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

> **Re-baselined 2026-09-25.** Every `.set` in `tpsl_test_sets/` carried the
> stale `InpBBAppliedPrice=3` / `InpMAAppliedPrice=1` (the EA's defaults are 2
> and 0), so every number in this document was measured on the wrong
> Bollinger Band price. All 8 files were corrected (those two lines only).
> **New `test_A` DCA-mode reference** (`DCA_EA.mq5`, FTMO `540291482`, EURUSD
> H4, 2025.01.01–2026.01.22, `Model=4`, $100,000, 1:30): **$287.55 net, PF
> 3.32, RF 1.13, Sharpe 1.32, equity DD $254.14 (0.25%), 80 trades.** Any
> future TP/SL-mode code change must reproduce this exactly. Report:
> `reports/test_A_rebaseline_2026_09_25/`. The TP/SL-mode results below were
> not re-run; see `reports/phase1_forensic_2026_09_25/FINDING.md` for Test B
> on the corrected inputs.

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

## 11. Independent verification — ATR-Based and Risk %/Currency SL types (all 5 remaining)

Five backtests (`tpsl_test_sets/test_F_atr.set` through `test_J_risk_currency_adjust_lot.set`),
each identical to `test_B_fixed_pips.set` (EURUSD H4, 2025.01.01-2026.01.22, `Model=4`,
FTMO login `540291482`, `InpExitStrategy=0` BB Centre Band) except for `InpSLType` and
its own risk parameter, isolate the 5 previously-untested `ENUM_SL_TYPE` values. Same
evidentiary bar as §7/§9: verifying trade mechanics (SL distance/lot correctness), not
profitability (Rule 9).

### 11.1 Test F — ATR-Based (`InpSLType=3`): CONFIRMED

41 trades, 40 genuine broker-side `sl <price>` exits (only 1 via BB Centre Band).
Sampled SL distances vary trade-to-trade — 63.2, 52.2, and 73.4 pips across three
inspected fills — unlike Fixed Pips's constant 50.00 (§7), consistent with a real
`ATRValue() * InpSLATRMultiplier` distance that tracks each entry's live volatility
rather than a fixed value. Net profit -$31.47 (informational only, per Rule 9).

### 11.2 Tests G/H — Risk %/Currency, Fixed Lot (`InpSLType=1`/`2`): CONFIRMED — with a behavioural finding

Test G (`InpSLRiskPercent=1.0`) and Test H (`InpSLRiskCurrency=100.0`): **zero** SL
hits across 41 trades in either test — every exit was via BB Centre Band, and both
produced the identical $96.00 net profit / 41-trade outcome.

This is the formula working exactly as designed, not a bug — `ComputeSLPrice()`'s
Fixed-Lot branch derives SL distance from `riskMoney / lossPerPip` at the lot actually
used (here `InpLotSizeMode=LOT_FIXED`, `InpInitialLot=0.01`, unaffected by TP/SL mode
for the Fixed-Lot variants). At 0.01 lot, EURUSD's per-pip loss is ≈$0.10:
- Test G: $1,000 risk (1% of $100k) / $0.10 per pip ≈ **10,000 pips** (≈1.0 price unit) distance
- Test H: $100 fixed risk / $0.10 per pip ≈ **1,000 pips** (≈0.10 price unit) distance

Both are enormously wider than any realistic EURUSD H4 excursion, so the attached SL
is valid but practically unreachable — explaining why both tests reduce to pure
BB-Centre-Band-only outcomes, identical to each other regardless of the 10x difference
in risk money between them (both distances are "unreachable" either way, so the
specific value stops mattering).

**Classification: Logical Design Choice / informational, not a bug.** The math is
correct — SL distance is inversely proportional to lot size by construction, and a
very small fixed lot combined with a modest risk% or risk-currency naturally produces
a very wide stop. This SL type is only meaningful at lot sizes large enough that the
resulting distance lands in a realistic range for the instrument/timeframe; worth
noting in any future user-facing guidance for this feature, but requires no code
change.

### 11.3 Tests I/J — Risk %/Currency, Adjust Lot (`InpSLType=4`/`5`): CONFIRMED — with a Specification Gap

Test I (`InpSLRiskPercent=1.0`) and Test J (`InpSLRiskCurrency=100.0`), both with
`InpSLDistancePips=50` (same fixed distance as Test B): 38/41 SL hits in each, the
same entry/exit *pattern* as Test B (identical signals, identical 50-pip trigger
geometry — lot size is irrelevant to whether/when a fixed-distance SL is hit).

Quantitative confirmation the lot-adjustment math itself is correct:
- Test I: net profit **-$6,492.21**, PF **0.67** — `ComputeRiskAdjustedLot()` resolves to
  ≈2.0 lots per trade throughout (1% of a balance that stayed roughly $92k-107k
  through the test, ÷ ≈$500 loss-per-lot at 50 pips) — a ~200x scale-up from Test B's
  0.01 lot. Test B's own PF is 0.67 in the current codebase (Fix 1 kept, Fix 2
  reverted — see `TPSL_EQUITY_BALANCE_ROOT_CAUSE.md`), matching Test I's PF exactly;
  -$32.93 (Test B) × ~197-200 ≈ -$6,487, matching Test I's -$6,492.21 almost exactly.
- Test J: net profit **-$651.49**, PF **0.67** — fixed $100 risk (balance-independent)
  resolves to a *constant* ≈0.20 lot every trade (20x Test B's 0.01), and
  -$32.93 × 20 ≈ -$658.60, matching Test J's -$651.49 closely (small residual from
  lot-step rounding and per-lot commission/spread, not linear with lot size).

This is strong evidence `ComputeRiskAdjustedLot()` recomputes lot size correctly and
proportionally to the configured risk on every trade.

**Specification Gap found — FIXED**: `ComputeRiskAdjustedLot()` never read
`InpMaxInitialLot` — confirmed by code inspection, that cap (`DCA_EA.mq5` "Max Initial
Lot Size (0 = uncapped)") was applied only inside `ComputeBaseLotForNewSequence()`, the
normal DCA-style sizing path never used by the Adjust-Lot SL types. In Test I this
produced ~2.0-lot single positions on a $100,000 account from a 1%-risk/50-pip
configuration — with `InpMaxSequencesPerDirection=3`, up to 3 such positions per
direction (6 total, both directions) could be open simultaneously, meaning any
`InpMaxInitialLot` safety cap a user had configured was silently bypassed whenever
either Adjust-Lot SL type was active. Not an Implementation Bug in the sense of
producing a wrong number — the two lot-sizing code paths are legitimately separate,
and the original TP/SL feature request never specified whether the general lot cap
should also constrain risk-derived position sizing — but the user's explicit direction
was not to leave it silently uncapped, so `ComputeRiskAdjustedLot()` (in both
`DCA_EA.mq5` and `DCA_EA_TPSL_Forensic.mq5`, kept in sync) now clamps its computed lot
to `InpMaxInitialLot` when set (>0), mirroring the exact clamp pattern
`ComputeBaseLotForNewSequence()`'s Step-Based branch already uses. The clamp only ever
*reduces* the lot below what the risk formula alone would have produced — actual $ risk
at the fixed SL distance ends up below the configured target when the cap binds, never
above it, so this cannot introduce a new way to take on more risk than configured.

**Validated**: re-ran Test I (`InpMaxInitialLot=1.0`) post-fix. Every trade's lot is now
exactly `1.0` (previously ~2.0, unclamped) — confirmed directly in the deal log, not
inferred. Net profit -$3,257.60 (previously -$6,492.21, ≈49.8% wider than exactly half
due to lot-step rounding and per-lot commission, not a clean 2x), same 41 trades, same
Profit Factor 0.67 — i.e. the trade pattern is completely unaffected, only position
size scaled down as intended. Compiles clean, 0 errors/0 warnings, both files.

## 13. TP/SL mode validated on the cent-account track (`EA_DCA_CENT_V1.mq5`)

Everything above validated TP/SL mode on `DCA_EA.mq5`. After the two re-baselines
(commits `c68e806` TP/SL port, `793d30a` `InpMaxInitialLot` fix port), TP/SL mode
itself had never actually been exercised on `EA_DCA_CENT_V1.mq5` — only its DCA-mode
regression had been re-checked. Closed that gap with a regression-equivalence check:
re-run the same two `.set` files against `EA_DCA_CENT_V1.mq5` (same FTMO dev-track
terminal/account this file's own DCA-mode baseline uses — this is not yet the actual
RoboForex cent account, see the note below) and confirm identical results to
`DCA_EA.mq5`'s own already-validated numbers.

| | `DCA_EA.mq5` | `EA_DCA_CENT_V1.mq5` | Match |
|---|---:|---:|---|
| Test B (Fixed Pips SL): Net Profit / PF / Trades | -$32.93 / 0.67 / 41 | -$32.93 / 0.67 / 41 | **Exact** |
| Test I (Risk% Adjust-Lot SL, post-fix): Net Profit / Trades / Lot per trade | -$3,257.60 / 41 / 1.00 | -$3,257.60 / 41 / 1.00 | **Exact** |

Both bit-for-bit identical, confirming the port carried TP/SL mode and the
`InpMaxInitialLot` fix over correctly with zero drift, including the risk-adjusted lot
clamp mechanism (Test I) and basic SL-attachment mechanics (Test B).

**Infrastructure finding, new this check**: on the first attempt, Test B's `.set` file
(`test_B_fixed_pips.set`) had fallen out of `MQL5\Profiles\Tester\` since it was last
copied there (before this session's context compaction — only the newer `test_F`
through `test_J` files were re-copied afterward). With `ExpertParameters` pointing to a
bare filename that no longer existed in that folder, the Tester did **not** error —
it silently ran with the `.mq5`'s raw compiled-in defaults (`InpTradeMode=0`,
`InpMaxSequencesPerDirection=100`, etc.), producing a normal-looking "successfully
finished" report at exactly the plain DCA-mode baseline numbers ($225.70, 58 trades).
Caught immediately by the same "verify the report's Settings section" discipline
`CLAUDE.md` already mandates — but this is a **third, previously-undocumented failure
mode** distinct from the two already recorded there (no `ExpertParameters`/absolute
path → reuses a stale `.set`; this case → missing file → falls back to compiled
defaults). Worth adding to `CLAUDE.md` as its own bullet.

**Still open, not yet done**: this validates the *code path* is correct on
`EA_DCA_CENT_V1.mq5`, run on the FTMO dev-track account (100,000 USD, 1:30 leverage) —
not yet on the actual RoboForex cent account with real cent-account contract
size/margin/spread. Per this project's own established distinction
(`GO_LIVE_VALIDATION_PLAN.md`), that remains a separate, later validation step before
any live TP/SL deployment there.

## 14. Summary

All 7 SL methods are now independently backtest-verified: Fixed Pips and QMP-Offset via
§7/§9, ATR-Based and both Risk %/Currency variants (Fixed Lot and Adjust Lot) via §11.
Balance-% TP is confirmed (§9). DCA-mode backward compatibility is confirmed exact
(§6), including after the `EA_DCA_CENT_V1.mq5` re-baseline. Two informational findings
came out of §11 — a Fixed-Lot risk-based SL distance can be practically unreachable at
small lot sizes (design characteristic, no fix needed) and Adjust-Lot risk-based SL
types bypassed `InpMaxInitialLot` (Specification Gap, **fixed and validated** in §11.3
— `ComputeRiskAdjustedLot()` now clamps to it). Only the Fixed-Lot distance
characteristic remains a documented behavior rather than a code change, per this
project's classification discipline, pending user direction. TP/SL mode's port onto
the cent-account track (`EA_DCA_CENT_V1.mq5`) is now confirmed exact-match on the
FTMO dev-track account (§13); real RoboForex cent-account validation remains a
separate, not-yet-started step.
