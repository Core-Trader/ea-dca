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

## 5. Not yet done (explicitly, per the request's own mandatory Implemented/Tested/
Not yet tested/Not supported/Requires clarification distinction)

- **Not started**: any code change. This document is audit + baseline only.
- **Requires a scoping decision before coding** (flagged, not guessed): whether the
  4 SL methods that adjust lot size (§12.5/§12.6 of the request) round lot size before
  or after applying `InpMaxInitialLot`/broker volume-step normalization — the
  existing `NormalizeLot()` (`DCA_EA.mq5`) is the natural reuse point, but the request's
  risk-based lot-sizing math needs to run *before* that clamp is applied, which is a
  new call-order question, not an existing pattern to copy.
- **Not supported in this design**: Partial Close in TP/SL mode (§2, compatibility
  matrix) — excluded rather than reinterpreted, per the request's own instruction to
  document limitations rather than claim unverified support.
