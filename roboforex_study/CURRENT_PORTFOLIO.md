# Current RoboForex Cent-Account Portfolio — 7 Symbols

**Status**: first-cut deployment candidate, not a final recommendation. Assembled
from `SYMBOL_SCREENING_REPORT.md`'s existing portfolio plus its 4 Tier 1
candidates. **Update 2026-09-19**: wider-window/out-of-sample validation
(report §D) found and investigated (§D2) a real drawdown episode on USDCAD —
resolved as a genuine but self-recovering near-miss, decided to keep in the
portfolio as-is (circuit breaker still off). Denser parameter-sensitivity
check, walk-forward, and Monte Carlo are still open. **This is a working
baseline to continue adjusting, not a go-live sign-off.**

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
> tested (breaker-off) configuration, pending the remaining walk-forward/Monte
> Carlo work. Revisit if either of those surfaces further concerns.

## Composition

| Symbol | Role | Basis |
|---|---|---|
| EURUSD | Existing portfolio | `GO_LIVE_VALIDATION_PLAN.md` Phase 1-3, `ROBOFOREX_MULTI_SYMBOL_STUDY.md` |
| GBPUSD | Existing portfolio | Same |
| USDJPY | Existing portfolio | Same — carries known elevated equity DD (4.2-4.7% across every test run so far), kept in per this study's own finding that it's also the single most profitable symbol tested; risk/reward tradeoff, not an oversight |
| AUDUSD | Tier 1 candidate | `SYMBOL_SCREENING_REPORT.md` §B — most structurally robust symbol in the whole screen (tightest DD band, 0.13-0.69% across the full 49-combo grid, zero losing combinations), lowest correlation to the existing 3 (0.03-0.22) |
| USDCHF | Tier 1 candidate | Same §B — clean, stable grid, meaningful optimization improvement without degrading risk-adjusted quality. Highest correlation to the existing portfolio of the 4 candidates (0.23 vs EUR/JPY on the equity measure) and co-drawdows with USDJPY in Apr 2025 — kept in, but see the note below |
| USDCAD | Investigated, kept in as-is | Same §B screening looked clean, but the 1-year window missed a real 10.17% equity DD episode; trade-level investigation (§D2) found it was a genuine but ultimately self-resolving near-miss (~$453 realized loss, not a stop-out). Circuit breaker deliberately left off for now (see warning above) |
| CADCHF | Tier 1 candidate | Same §B — tightest DD band alongside AUDUSD, near-zero correlation to the existing portfolio, gave the single largest combined-portfolio drawdown reduction of the 4 candidates in §C's equity analysis |

**Quantitative diversification evidence** (`SYMBOL_SCREENING_REPORT.md` §C):
combined equity drawdown for all 7 together is **0.77%**, against 1.43% for the
existing 3 alone and 4.28% for USDJPY standalone — a real, measured
diversification benefit, not an assumption.

**Known open concern, not yet resolved**: USDCHF and CADCHF correlate with each
other at 0.34 (the highest pair in the whole matrix) and have a real overlapping
drawdown episode in January 2026. Both are included here since each individually
still reduces combined portfolio risk, but §D item 6 (not yet run) specifically
checks whether running both together adds materially less benefit than either
paired with AUDUSD/USDCAD alone.

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
  order above:

  | Symbol | Magic Number |
  |---|---:|
  | EURUSD | 123456 |
  | GBPUSD | 123457 |
  | USDJPY | 123458 |
  | AUDUSD | 123459 |
  | USDCHF | 123460 |
  | USDCAD | 123461 |
  | CADCHF | 123462 |

## Files

`roboforex_study/sets/cent_portfolio/<SYMBOL>.set` — one file per symbol.
Content is identical **except** `InpMagicNumber`, per the table above (MT5
`.set` files don't encode which symbol to trade; that's determined by which
chart the EA is attached to — the magic number is the only per-symbol
difference between these 7 files).

**Target EA**: `EA_DCA_CENT_V1.mq5` (the cent-account track build, currently at
commit `793d30a` — InpMaxInitialLot fix applied to the risk-adjusted lot-sizing
path). **Account**: RoboForex-Pro, Login `52010662`.

## Deployment checklist (for when you're ready, not done here)

- [x] **USDCAD decision made 2026-09-19**: deploy alongside the other 6,
      circuit breaker deliberately left off, pending walk-forward/Monte Carlo
- [ ] Decide on the Max Floating Loss circuit breaker threshold before committing
      live capital, given it's currently off
- [ ] Attach `EA_DCA_CENT_V1.mq5` to charts (one per symbol above), H4,
      loading the matching `.set` file on each
- [ ] Confirm each chart's Magic Number collision check passes (expected: yes,
      all different symbols)
- [ ] Re-confirm `SYMBOL_SCREENING_REPORT.md` §E's still-open items before
      trusting this composition long-term (denser parameter grid, walk-forward,
      Monte Carlo, USDCHF-CADCHF co-dependency)
