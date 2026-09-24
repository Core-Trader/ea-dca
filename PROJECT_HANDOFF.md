# EA-DCA-V1.0 — Project Handoff

**Last updated**: 2026-09-24, as of commit `20edace` (the commit adding this
update will be one ahead of that by the time you read it).

> **Maintenance note**: this is a living document, not a snapshot. Update it
> whenever a workstream's status changes, a decision gets made, or a major
> finding surfaces — the same day, in the same commit if practical. If you're
> reading this and it looks like it might be stale, check `git log -20`
> against its claims before trusting it. This document replaces a one-time
> bootstrap file of the same name from the project's very first commit
> (`87b3843`), deleted a commit later once its purpose was served — this one
> is meant to stay current for the life of the project instead.

**Read this first** for current status. Read `INDEX.md` for repo structure
("what's where"). Read `CLAUDE.md` for working rules and technical gotchas
before making any change. This file duplicates neither — it's the "where do
things actually stand" layer between them.

---

## 1. What this project is

A Bollinger-Band/QQE-driven DCA (dollar-cost-averaging) MetaTrader 5 Expert
Advisor, its cent-account variant, a TP/SL single-position trading mode, and
the go-live/multi-symbol research built around them. Full structural
breakdown: `INDEX.md`.

## 2. Workstream status

### A. Core EA (`DCA_EA.mq5`) — stable, both trading modes complete

- **DCA mode**: mature. Original build validated phase-by-phase against the
  functional spec and against the reference EA's own behavior
  (`reports/`).
- **TP/SL mode**: fully implemented (all 7 SL methods, Balance-% TP exit),
  fully tested (every SL type independently backtest-verified — see
  `tpsl_mode/TPSL_MODE_AUDIT.md`'s own status table, no open items). The
  Balance/Equity divergence root-cause investigation is closed: Fix 1
  confirmed and kept, Fix 2 tested and rejected (see
  `tpsl_mode/TPSL_EQUITY_BALANCE_ROOT_CAUSE.md`).
- **Not yet ported**: the validated TP/SL feature has not been ported into
  `EA_DCA_CENT_V1.mq5` (the cent-account track EA) — `DCA_EA.mq5` and
  `EA_DCA_CENT_V1.mq5` still diverge only by the cent-account-specific Max
  Floating Loss circuit breaker, per `EA_DCA_CENT_V1.mq5`'s own header.

### B. FTMO go-live validation track — paused, one open decision

- `go_live/GO_LIVE_VALIDATION_PLAN.md` Phases 1-9 complete: environment
  audit, cent-account risk categorization, baseline backtests, sensitivity
  sweeps, Monte Carlo, circuit-breaker design, genetic optimization, OOS
  validation.
- **Open, unresolved decision**: Safe vs Linear multiplier system for the
  cent-account track. Genetic optimization found Safe dominates Linear on
  every risk-adjusted metric (Sharpe, Recovery Factor, lowest equity DD) —
  except it underperforms Linear specifically during one strongly-trending
  OOS window. Never decided, not revisited since it was first found. Not
  urgent, but also not forgotten — pick this up whenever the RoboForex
  track (below) isn't the priority.

### C. RoboForex multi-symbol study — 6-symbol portfolio, re-validated clean 2026-09-24

- Real funded cent account (RoboForex-Pro, Login `52010662`). Screened the
  full Market Watch universe for portfolio-diversification candidates,
  originally landed on a 7-symbol portfolio: EURUSD/GBPUSD/USDJPY (existing)
  + AUDUSD/USDCHF/USDCAD/CADCHF (Tier 1 candidates). **USDCAD was dropped
  2026-09-24** (see below) — the deployed portfolio is now 6 symbols; every
  reference to "7 symbols" elsewhere in this section describes the study's
  history, not the current deployment target. Full validation backlog
  completed — wider-window/OOS, trade-level investigation of a USDCAD
  drawdown episode, dense parameter-cliff check, walk-forward, Monte Carlo,
  USDCHF/CADCHF co-dependency check. All findings and reasoning:
  `roboforex_study/SYMBOL_SCREENING_REPORT.md`. Live-facing summary:
  `roboforex_study/CURRENT_PORTFOLIO.md`.

- **⚠ Found 2026-09-20, spot-checked 2026-09-23**: `InpBBAppliedPrice` was
  wrong (`3`/PRICE_LOW instead of the EA's actual default, `2`/PRICE_HIGH)
  throughout the entire study — traced to a stale reference `.set` file used
  when the study was set up. Fixed in all 13 source `.set` files. A 1-year
  spot-check (all 7 portfolio symbols, headless, corrected value confirmed
  via each report's own Settings section — full delta table:
  `roboforex_study/BACKTEST_VIABILITY_CHECKLIST.md` §4) found this was not
  cosmetic:
  - **USDJPY's long-cited "elevated equity DD" (4.2-4.7%) drops to 0.60%**
    under the corrected price basis — largely a bug artifact, not a real
    property of the symbol. Its PF (5.99) and Recovery Factor (2.81) are
    now among the best of the 7, not the reason it needed a risk/reward
    justification to stay in the portfolio.
  - **USDCAD's Equity DD worsens (1.33%→3.38%) and Recovery Factor
    collapses further (1.00→0.47)** — its already-flagged risk-outlier
    status is reinforced, not resolved. The 2026-09-19 decision to keep it
    in with the circuit breaker off was made without this data point.
  - **AUDUSD's profit dropped 33%** and Recovery Factor dropped
    meaningfully — no longer clearly *the* standout candidate.
  - No symbol flipped to a net loss; nothing catastrophic. But this is the
    "materially different" outcome, not "looks broadly similar" — per the
    checklist's own decision framework, a full re-validation is now more
    justified than a spot-check-and-move-on.

- **2026-09-23, USDCAD OOS-B re-run specifically**: given the choice between
  running the full battery again or a scoped USDCAD-focused check first, ran
  the latter — the exact §D2 OOS-B window (2026.03.01–2026.09.19)
  re-executed with the corrected `.set`. Result: the window **flips from
  breakeven to a real net loss** (Net Profit $6.17→-$34.20, Profit Factor
  1.01→0.95, Recovery Factor 0.00→-0.02), while the dollar-value drawdown
  episode itself is essentially unchanged (~$1,554, same structural event).
  A resampling Monte Carlo on this window's own 50 trades puts P(net-negative
  path) at 22.58%. This is the seventh independent line of evidence against
  USDCAD, and the first to show an outright loss rather than a
  weak-but-positive result. Full detail: `CURRENT_PORTFOLIO.md`'s USDCAD
  warning block, data in `roboforex_study/reports/usdcad_oosb_refix/`.

- **2026-09-24, circuit breaker tested at 8%, made it worse**: tested
  `InpUseMaxFloatingLoss=true` at 8% against the same OOS-B window. Net loss
  deepened from -$34.20 to **-$1,181.28** — the breaker fired once
  (2026-06-23), force-closing 15 stacked legs for a ~$1,201 realized loss
  **2 days before** the adverse move's actual peak, crystallizing the loss
  right before the historical mean-reversion that (with no breaker) let it
  recover to a much smaller ~$453 loss. Confirms the EA's own documented
  Equity-Protection-at-low-thresholds failure mode applies here too. Not a
  verdict on the breaker concept — a verdict on this one threshold for this
  one historical episode; a higher threshold remains untested. Detail:
  `CURRENT_PORTFOLIO.md`'s USDCAD block,
  `roboforex_study/reports/usdcad_breaker_test/FINDING.md`.

- **2026-09-24, USDCAD dropped from the deployed portfolio — "for now," not
  permanent**: given seven independent lines of evidence all pointing the
  same direction and the failed 8% breaker test, decided to drop USDCAD
  rather than keep tuning around it or deploy accepting the risk as-is.
  Supersedes the 2026-09-19 "deploy as-is, breaker off" decision.
  `USDCAD.set`/`USDCAD_breaker8pct.set` and the full investigation trail
  stay in the repo — a higher breaker threshold (11-12%) remains untested
  if there's appetite to revisit later. `CURRENT_PORTFOLIO.md` updated
  throughout to reflect the 6-symbol deployed portfolio
  (EURUSD/GBPUSD/USDJPY/AUDUSD/USDCHF/CADCHF).

- **2026-09-24, full re-validation completed for the 6-symbol set — clean
  across the board**: re-ran the combined-portfolio diversification analysis
  (6 fresh `EA_DCA_CENT_V1_EquityForensic` runs) and the full wider-window/
  OOS + dense parameter-cliff + walk-forward battery for AUDUSD/USDCHF/
  CADCHF (33 backtests + 3 genetic optimizations, ~11 min headless). Result:
  combined 6-symbol equity DD is **0.32%**, an improvement over the old
  7-symbol (USDCAD-included) figure of 0.77% — dropping USDCAD didn't just
  remove a risk outlier, it measurably improved the portfolio. AUDUSD/
  USDCHF/CADCHF show **zero negative windows** across 9 wider-window/OOS
  runs and 15 walk-forward windows, and **zero parameter-cliffs** across 363
  dense-grid combinations (121 × 3) — nothing resembling USDCAD's risk
  profile anywhere. **Caveat**: this batch used `Model=1` (1-minute OHLC),
  not this project's usual `Model=4`, a documented-different-results setting
  for this EA — treat as a clean fast screen, worth a `Model=4` spot-check
  before final sign-off, though nothing suggests the conclusion would
  change. Full detail:
  `roboforex_study/reports/revalidation_2026_09_24/FINDING.md`.

- **Next action, not yet decided**: whether a `Model=4` re-confirmation pass
  is worth doing on the more interesting windows above (e.g. USDCHF's
  Full/OOS-A 3.26% DD episode) before treating this re-validation as fully
  final — a scope/budget call, not resolved here. Otherwise, the RoboForex
  workstream's immediate open items are now resolved; remaining work is the
  lower-priority items below.

- **Explicitly not started, and shouldn't be until the above resolves**:
  testing alternate multiplier systems (only Linear has ever been tried
  here), a wider BB parameter range (only 20-50/1.5-3.0 tested), or exit
  strategies other than BB Centre Band. Starting any of these before the
  full re-validation risks building on a foundation that just proved
  unstable once already.

### D. Repo infrastructure — just migrated, convention changed

- **2026-09-20**: moved from OneDrive
  (`C:\Users\vasco\OneDrive\Documentos\000 Trading\001 EA Vault\EA-DCA-V1.0`)
  to `C:\DEV\EA-DCA-V1.0`. Old location may still exist pending manual
  deletion by the user — don't assume it's gone, but don't treat it as
  authoritative either; `C:\DEV\EA-DCA-V1.0` is the one true working copy
  going forward.
- **Same day**: converted the FTMO terminal from a live directory symlink to
  a plain, independently-maintained copy — matching RoboForex's own
  already-established convention. **Neither terminal is symlinked to this
  repo any more.** Both need `scripts\sync_to_terminals.ps1` run after any
  change to `src/experts/` or `src/indicators/`, or they'll silently run
  stale code. Full detail: `CLAUDE.md`'s "Sync to terminals" section.
- **New tooling**: `scripts/verify_set_against_defaults.py` (diffs a `.set`
  against an EA's own compiled defaults — catches exactly the kind of
  silent drift that caused the §2C incident above; run it before starting
  any new study or building a new baseline `.set`).

## 3. Immediate next steps, in priority order

1. ~~Get the §2C checklist results back~~ — **done 2026-09-23**. Result:
   materially different, not a clean pass (USDJPY's risk profile
   overturned, USDCAD's reinforced, AUDUSD's softened). Warnings updated in
   `SYMBOL_SCREENING_REPORT.md`, `CURRENT_PORTFOLIO.md`, and here.
2. ~~Scoped USDCAD OOS-B + Monte Carlo re-check~~ — **done 2026-09-23**.
   Result: the OOS-B window flips from breakeven to a real net loss
   post-fix, with a 22.58% resampled chance of a net-negative path. Seventh
   independent line of evidence against USDCAD, and the most unambiguous
   yet. Detail: §2C above, `CURRENT_PORTFOLIO.md`'s USDCAD warning block.
3. ~~Test a circuit breaker threshold~~ — **done 2026-09-24, 8% tested,
   made the outcome worse, not better** (net loss deepened from -$34.20 to
   -$1,181.28 — breaker fired 2 days before the adverse move's historical
   peak, crystallizing a loss the position would otherwise have mostly
   recovered from). Detail: §2C above,
   `roboforex_study/reports/usdcad_breaker_test/FINDING.md`.
4. ~~Decide USDCAD's disposition~~ — **done 2026-09-24: dropped from the
   deployed portfolio, "for now."** Deployed portfolio is 6 symbols
   (EURUSD/GBPUSD/USDJPY/AUDUSD/USDCHF/CADCHF). `USDCAD.set` and its
   investigation trail kept in the repo, not deleted — a higher breaker
   threshold (11-12%) remains untested if there's appetite to revisit.
5. ~~Run the full validation stack again for AUDUSD/USDCHF/CADCHF, and
   re-run the combined-portfolio diversification analysis for the 6-symbol
   set~~ — **done 2026-09-24, clean across the board.** Combined DD improved
   to 0.32%; zero negative windows across 9 wider-window/OOS + 15
   walk-forward runs; zero parameter-cliffs across 363 dense-grid combos.
   Used `Model=1` for speed — a `Model=4` re-confirmation on the more
   interesting windows remains a worthwhile, not urgent, follow-up. Detail:
   §2C above, `roboforex_study/reports/revalidation_2026_09_24/FINDING.md`.
6. Delete the old OneDrive project folder once satisfied the new location
   works (user's own manual step, not blocking anything).
7. Lower priority, pick up whenever there's appetite: the Safe-vs-Linear
   multiplier decision (§2B), porting TP/SL mode into `EA_DCA_CENT_V1.mq5`
   (§2A), and the explicitly-deferred multiplier/BB-range/exit-strategy
   expansion for RoboForex symbols (§2C) — the last of these still
   shouldn't start before #2 resolves.

## 4. Where the durable rules live (not duplicated here)

`CLAUDE.md` — git discipline, the sync-to-terminals workflow, Strategy
Tester gotchas (headless config pitfalls, login drift, tick-cache
instability), and the `.set`-verification tool. Read it before any
nontrivial change, not just once at project start.
