# Current RoboForex Cent-Account Portfolio — 6 Symbols

> ✅ **Full re-validation for the 6-symbol set completed 2026-09-24 — clean
> across the board.** Combined-portfolio diversification re-checked under
> corrected settings: **0.32% combined equity DD**, better than the old
> 7-symbol (USDCAD-included) figure of 0.77%. AUDUSD/USDCHF/CADCHF each
> re-run through the full wider-window/OOS, dense parameter-cliff, and
> walk-forward battery (33 backtests + 3 optimizations total) — **zero
> negative windows, zero parameter-cliffs, nothing resembling USDCAD's risk
> profile anywhere**. One caveat: this batch used `Model=1` for speed, not
> this project's usual `Model=4` — a confirmed-different-results setting for
> this EA (`CLAUDE.md`), so treat these as a clean fast screen, not a final
> `Model=4`-confirmed sign-off. Full detail:
> `roboforex_study/reports/revalidation_2026_09_24/FINDING.md`.

> ⚠ **USDCAD dropped from the deployed portfolio, 2026-09-24 — "for now",
> not a permanent disqualification.** After the corrected-price-basis
> re-checks below made USDCAD's risk profile progressively worse (not
> better) across seven independent lines of evidence, and an 8% circuit
> breaker threshold test made its worst episode *more* damaging rather than
> less (see the dedicated warning block further down), the decision was to
> drop it rather than keep tuning around it. **The deployed portfolio is now
> EURUSD/GBPUSD/USDJPY/AUDUSD/USDCHF/CADCHF (6 symbols)** — `USDCAD.set`
> and all its investigation history are kept in this repo for reference and
> a possible future revisit (e.g. a higher breaker threshold not yet
> tested, or renewed interest after the full re-validation battery below),
> not deleted. Every mention of "7 symbols" elsewhere in this file and in
> `SYMBOL_SCREENING_REPORT.md` predates this decision.

> ⚠ **`InpBBAppliedPrice` fix spot-checked 2026-09-23 — two symbols'
> standing genuinely changed, not just their exact numbers.** All 7 `.set`
> files below are corrected (`InpBBAppliedPrice=2`). A 1-year spot-check
> (`BACKTEST_VIABILITY_CHECKLIST.md`) found: **USDJPY's equity DD drops from
> 4.69% to 0.60%** — its long-standing "elevated risk, kept in for the
> profit" framing (see the composition table below) turns out to have been
> largely a symptom of the bug, not a real property of the symbol. **USDCAD's
> equity DD worsens (1.33%→3.38%) and Recovery Factor collapses further
> (1.00→0.47)** — its already-flagged risk-outlier status is reinforced, not
> resolved, by the correction. AUDUSD's profit and Recovery Factor both
> dropped meaningfully (-33% profit) — no longer clearly *the* standout
> candidate. This was one window, not the full OOS/walk-forward/Monte Carlo
> battery this portfolio's composition originally rested on — **that full
> re-validation is more justified now than before the spot-check**, and the
> USDCAD circuit-breaker-off decision specifically (below) was made without
> this data point. Full detail and delta table:
> `BACKTEST_VIABILITY_CHECKLIST.md` §4.

**Status**: first-cut deployment candidate, not a final recommendation. Assembled
from `SYMBOL_SCREENING_REPORT.md`'s existing portfolio plus its 4 Tier 1
candidates. **Update 2026-09-19**: the full validation backlog (§D2-§D6 —
wider-window/OOS, trade-level investigation, dense parameter-cliff check,
walk-forward, Monte Carlo, USDCHF/CADCHF co-dependency) is complete. **Update
2026-09-23**: that entire backlog ran under the `InpBBAppliedPrice` bug (see
warning above) — a spot-check under the corrected value found USDJPY's risk
profile and AUDUSD's standout status were both largely artifacts of the bug,
and USDCAD's risk-outlier status got worse, not better. **This is a working
baseline to continue adjusting, not a go-live sign-off**, and less settled
than the 2026-09-19 update implied — a full re-validation is now the more
honest next step, not just remaining deployment decisions. **Update
2026-09-24**: USDCAD dropped from the deployed portfolio (see the dedicated
warning above) — this document's portfolio is now 6 symbols, not 7.

> ⚠ **USDCAD downgraded from Tier 1 — investigated, a genuine near-miss, not
> disqualifying but not risk-free.** Out-of-sample testing found a real 10.17%
> equity drawdown (2026-05-11 to 07-06); trade-level investigation
> (`SYMBOL_SCREENING_REPORT.md` §D2) traced it to 3 concurrent SELL sequences
> all averaging into a genuine 590-pip, 8-week USDCAD uptrend simultaneously —
> the same structural mechanism already documented for USDJPY's earlier
> stress-test blowup, just far milder here. **It resolved itself**: BB Centre
> Band exit closed the stacked position on 2026-07-17 for a real but moderate
> ~$453 realized loss, not a forced stop-out — the strategy's own
> mean-reversion design worked as intended. But for 8 weeks, Balance showed
> almost nothing wrong (DD stayed ~3.2%) while Equity was down over 10% — a
> real risk window invisible on the easy-to-glance-at metric. **Decided
> 2026-09-19**: keep the Max Floating Loss circuit breaker disabled for now
> (not deploying it yet) — USDCAD stays in the portfolio as-is, matching its
> tested (breaker-off) configuration. Walk-forward (§D4) and Monte Carlo
> (§D5) both reinforced this risk profile afterward (a second losing window,
> outlier status on a fifth method) without changing the decision. **Update
> 2026-09-23**: the `InpBBAppliedPrice` spot-check adds a sixth data point,
> and it's the least ambiguous one yet — Recovery Factor collapses further
> (1.00→0.47) and Equity DD worsens (1.33%→3.38%) under the *corrected*
> price basis. The 2026-09-19 decision was made without this — worth
> deciding again, not assuming it still stands. See
> `BACKTEST_VIABILITY_CHECKLIST.md` §4 for the full comparison.
>
> **Update 2026-09-23, OOS-B specifically re-run**: the exact OOS-B window
> from §D2 (2026.03.01–2026.09.19) was re-run with the corrected
> `InpBBAppliedPrice=2`. The dollar-value drawdown episode is essentially
> unchanged (~$1,554, confirming it's the same structural event — 3
> concurrent SELL sequences into the same USDCAD uptrend), but the window's
> **overall result flips from breakeven to a real net loss**: Net Profit
> $6.17→**-$34.20**, Profit Factor 1.01→**0.95**, Recovery Factor
> 0.00→**-0.02** (50 trades, down from 65 pre-fix — same signal-timing
> shift seen across the rest of the study). This is the first re-validated
> USDCAD window to show an outright loss, not just a weak-but-positive
> result. A trade-resampling Monte Carlo (20,000 paths, pooled from this
> window's own 50 closed legs) puts **P(net-negative path) at 22.58%**
> (4,516/20,000) — not directly comparable to §D5's original 0.33% figure
> (that pooled all 225 trades across 2.7 years; this pools only the
> adverse window itself), but a real, seventh independent data point, and
> the most unambiguous one yet. One caveat: this resampling (inherited
> unmodified from `monte_carlo_bootstrap.py`) pools only the deal-level
> Profit column, excluding Swap — a real ~$229 drag here from multi-week-held
> DCA legs during the trend, which resampling can't capture since it accrues
> with holding time, not per-trade luck, so the true negative-outcome
> probability in live trading likely runs somewhat higher than 22.58%. Full
> data: `roboforex_study/reports/usdcad_oosb_refix/`.
>
> **Update 2026-09-24, circuit breaker tested at 8%, made it worse, not
> better**: tested `InpUseMaxFloatingLoss=true` at `InpMaxFloatingLossPercent
> =8.0` against this same OOS-B window. Result: net loss **deepened** from
> -$34.20 to **-$1,181.28** (Profit Factor 0.95→0.04, Recovery Factor
> -0.02→-0.95), even though Equity DD *did* shrink as designed (10.35%→
> 8.28%). Mechanism, confirmed from the deal log: the breaker fired once, on
> 2026-06-23, force-closing 15 stacked legs simultaneously for a ~$1,201
> realized loss — **2 days before** the adverse move's actual peak
> (~2026-06-25, per §D2). Historically the position then reverted and exited
> for a much smaller ~$453 loss via the normal BB Centre Band exit; the 8%
> breaker crystallized the loss right before that recovery instead of
> letting it happen. Same failure mode this EA's own code already documents
> for Equity Protection at low thresholds — cuts a recovering position short.
> **Not evidence the breaker concept is bad, evidence this specific
> threshold was badly timed for this specific historical episode** — a
> higher threshold (nearer the 10.35% natural peak) would only fire if a
> *future* episode goes further than this one did, which is a real tradeoff,
> not resolved by this one test. Full write-up:
> `roboforex_study/reports/usdcad_breaker_test/FINDING.md`.
>
> **Decision 2026-09-24: dropped from the deployed portfolio, for now.**
> Given seven independent lines of evidence all pointing the same direction
> and a circuit-breaker threshold test that made the worst historical
> episode worse rather than better, the call was to drop USDCAD rather than
> keep tuning around it or deploy it accepting the risk as-is. This is
> explicitly **not** framed as permanent — `USDCAD.set` and this entire
> investigation trail stay in the repo, and a higher breaker threshold
> (11-12%) remains untested if there's appetite to revisit later.

## Composition

| Symbol | Role | Basis |
|---|---|---|
| EURUSD | Existing portfolio | `GO_LIVE_VALIDATION_PLAN.md` Phase 1-3, `ROBOFOREX_MULTI_SYMBOL_STUDY.md` |
| GBPUSD | Existing portfolio | Same |
| USDJPY | Existing portfolio | Same. Previously characterized as carrying elevated equity DD (4.2-4.7%) as a risk/reward tradeoff for its profitability — **the 2026-09-23 spot-check found this was largely an `InpBBAppliedPrice`-bug artifact: under the corrected value, DD drops to 0.60% and PF/Recovery Factor are among the best of the 7**. See the top-of-file warning; this row's original framing is now considered unreliable pending full re-validation. |
| AUDUSD | Tier 1 candidate | `SYMBOL_SCREENING_REPORT.md` §B — most structurally robust symbol in the whole screen (tightest DD band, 0.13-0.69% across the full 49-combo grid, zero losing combinations), lowest correlation to the existing 3 (0.03-0.22). **2026-09-23 spot-check**: profit and Recovery Factor both dropped meaningfully under the corrected price basis (-33% profit) — still solid, no longer clearly *the* standout. |
| USDCHF | Tier 1 candidate | Same §B — clean, stable grid, meaningful optimization improvement without degrading risk-adjusted quality. Highest correlation to the existing portfolio of the 4 candidates (0.23 vs EUR/JPY on the equity measure) and co-drawdows with USDJPY in Apr 2025 — kept in, but see the note below |
| ~~USDCAD~~ | **Dropped 2026-09-24** | Same §B screening looked clean, but the 1-year window missed a real 10.17% equity DD episode; investigated in depth (§D2, the checklist spot-check, an OOS-B re-check, and an 8%-threshold breaker test), and every one of those seven data points pointed the same direction. Dropped from the deployed portfolio rather than tuned around further — see the dedicated warning block above. `USDCAD.set` kept in the repo, not deleted. |
| CADCHF | Tier 1 candidate | Same §B — tightest DD band alongside AUDUSD, near-zero correlation to the existing portfolio, gave the single largest combined-portfolio drawdown reduction of the 4 candidates in §C's equity analysis |

**Quantitative diversification evidence — re-run 2026-09-24 for the current
6-symbol set** (`roboforex_study/reports/revalidation_2026_09_24/FINDING.md`
item 1): combined equity drawdown for all 6 deployed symbols together is
**0.32%**, against 0.48% for the existing 3 alone — an *improvement* over the
original 7-symbol (USDCAD-included) figure of 0.77%, not just a
like-for-like re-confirmation. Dropping USDCAD didn't just remove a risk
outlier from the roster, it measurably improved the combined-portfolio risk
profile, consistent with USDCAD having been the dominant contributor to that
combined drawdown all along. (Original 7-symbol figure, pre-fix/pre-drop,
for historical reference: `SYMBOL_SCREENING_REPORT.md` §C.)

**USDCHF/CADCHF co-dependency — checked, not a concern in practice**
(`SYMBOL_SCREENING_REPORT.md` §D6): they do correlate at 0.34 (the highest
pair in the matrix) and share a real overlapping drawdown episode in January
2026, but combining them still produces a strong result (1.06% combined DD)
and all 4 symbols together remains the single best combination tested
(0.77%). The effect turned out to be USDCHF's own weaker individual
diversification contribution, not a specific bad interaction with CADCHF —
no reason to drop either symbol.

## What's deliberately NOT changed from the tested configuration

- **Parameters are the study's DEFAULT set (`strategyA_bb_default.set`), not the
  Pass 2 "optimized" `InpBBPeriod`/`InpBBDeviation` combinations** — those were
  explicitly flagged in the screening report as candidate evidence needing
  further robustness testing (wider window, OOS, denser grid) before adoption,
  most pointedly after the EURJPY near-wipeout finding showed how close a
  dangerous parameter cliff can sit to an attractive-looking optimum. Using
  defaults here means every number in `SYMBOL_SCREENING_REPORT.md`'s
  "Default result" columns is the actual expected behavior of these `.set`
  files, not an untested extrapolation.
- **Max Floating Loss circuit breaker (`InpUseMaxFloatingLoss`) left disabled**,
  matching exactly what every backtest in this study actually exercised — a
  deliberate choice (confirmed with the user 2026-09-19), not an oversight. This
  is real cent-account risk-control functionality (`GO_LIVE_VALIDATION_PLAN.md`)
  that should be revisited before any live capital is committed, once a
  threshold has been deliberately chosen and tested for this specific
  multi-symbol context — not silently inherited from a single-symbol study.
- **Lot sizing (`InpInitialLot=0.01`, `LOT_FIXED`) and account-currency handling
  unchanged** — per this study's own earlier finding
  (`GO_LIVE_VALIDATION_PLAN.md` §5.3), RoboForex cent-account contract size and
  per-lot risk are not rescaled, only the balance display is, so no cent-specific
  adjustment to lot sizing is needed here.

## What's deliberately different from the tested configuration

- **Magic Number — distinct per symbol, not the shared `123456` every backtest
  in this study actually used.** User preference ("just in case", 2026-09-19),
  confirmed to cost nothing: magic number isn't read by any trading-decision
  logic anywhere in the EA (verified by inspecting every place it's used —
  `CheckMagicNumberCollision()`'s lock and `GetStateFilePath()`'s state-file
  name are both already keyed by Symbol+Magic *together*, not Magic alone, and
  every position/sequence re-validation checks Symbol and Magic together too —
  see `EA_DCA_CENT_V1.mq5:1922-1924`). Changing the number doesn't change
  trading behavior, so every backtest result in `SYMBOL_SCREENING_REPORT.md`
  still applies unchanged to these `.set` files despite the different numbers.
  Sequential from the project's original default, so EURUSD keeps the exact
  value (`123456`) every prior test used, and the rest increment by 1 in the
  order above. `123461` (USDCAD) is skipped in the deployed set below, not
  reassigned — reserved in case USDCAD is redeployed later:

  | Symbol | Magic Number |
  |---|---:|
  | EURUSD | 123456 |
  | GBPUSD | 123457 |
  | USDJPY | 123458 |
  | AUDUSD | 123459 |
  | USDCHF | 123460 |
  | ~~USDCAD~~ | ~~123461~~ (dropped, reserved) |
  | CADCHF | 123462 |

## Files

`roboforex_study/sets/cent_portfolio/<SYMBOL>.set` — one file per deployed
symbol (6, since USDCAD's drop). Content is identical **except**
`InpMagicNumber`, per the table above (MT5 `.set` files don't encode which
symbol to trade; that's determined by which chart the EA is attached to —
the magic number is the only per-symbol difference between these files).
`USDCAD.set` and `USDCAD_breaker8pct.set` remain in the same folder for
reference but are not part of the deployed set.

**Target EA**: `EA_DCA_CENT_V1.mq5` (the cent-account track build, currently at
commit `793d30a` — InpMaxInitialLot fix applied to the risk-adjusted lot-sizing
path). **Account**: RoboForex-Pro, Login `52010662`.

## Validation status (SYMBOL_SCREENING_REPORT.md)

- [x] Symbol screening across Market Watch + genetic optimization shortlist (§A/§B)
- [x] Portfolio correlation / diversification analysis (§C)
- [x] Wider-window (2024.01-2026.09) + out-of-sample validation (§D)
- [x] USDCAD drawdown episode — trade-level investigation (§D2)
- [x] Dense parameter-neighborhood cliff check, all 4 candidates (§D3)
- [x] Walk-forward rolling-window consistency check (§D4)
- [x] Monte Carlo trade-resampling bootstrap (§D5)
- [x] USDCHF-CADCHF co-dependency check (§D6)

**All backtesting/validation items are closed.** What remains is deployment
execution, not further testing:

## Deployment checklist (for when you're ready, not done here)

- [x] **Full validation stack re-run with corrected `InpBBAppliedPrice=2`**
      for AUDUSD/USDCHF/CADCHF — **done 2026-09-24**, clean across the board
      (zero negative windows in wider-window/OOS or walk-forward, no
      parameter cliffs, combined 6-symbol diversification improved to
      0.32%). One open caveat: run used `Model=1` for speed, not this
      project's usual `Model=4` — worth a `Model=4` spot-check on the more
      interesting windows before treating this as fully final. Detail:
      `roboforex_study/reports/revalidation_2026_09_24/FINDING.md`.
- [x] **USDCAD decision superseded 2026-09-24**: dropped from the deployed
      portfolio (not disqualified permanently — see warning above) after
      seven independent lines of evidence and a failed 8%-threshold breaker
      test. Supersedes the 2026-09-19 "deploy as-is, breaker off" decision.
- [x] **Max Floating Loss circuit breaker threshold**: tested at 8% for
      USDCAD specifically — made its worst episode worse, not better (see
      warning above). Remains off for the 6 deployed symbols, none of which
      have shown a drawdown episode remotely close to justifying it so far.
- [ ] Attach `EA_DCA_CENT_V1.mq5` to charts (one per symbol above), H4,
      loading the matching `.set` file on each
- [ ] Confirm each chart's Magic Number collision check passes (expected: yes,
      all different symbols)
