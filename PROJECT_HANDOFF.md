# EA-DCA-V1.0 — Project Handoff

**Last updated**: 2026-09-25, as of commit `a13dcff` (the commit adding this
update will be one ahead of that by the time you read it).

**Starting a new session or machine?** Paste `prompts/SESSION_HANDOFF.md`.

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
- **Already in the cent EA** (corrected 2026-09-25; this file previously said
  "not yet ported"): `EA_DCA_CENT_V1.mq5` carries TP/SL mode, confirmed
  trade-for-trade identical to `DCA_EA.mq5` (`tpsl_mode/TPSL_MODE_AUDIT.md`
  §13). The two EAs differ only by the cent-account Max Floating Loss
  circuit breaker. TP/SL mode has not been run on the RoboForex account.
- **TP/SL mode is not profitable yet — improvement work started 2026-09-25.**
  Plan agreed with the owner, each phase approved before its backtests:
  1. Diagnose with the forensic EA (**done**).
  2. Test on several symbols.
  3. Optimize TP/SL-only settings, tuned on one period and checked on a later
     unseen one.
  4. Change logic only if 1–3 show a real gap. Any change is gated to TP/SL
     mode, and DCA mode's deal lists must stay identical to the current build.

  **Phase 1 result** (`tpsl_mode/reports/phase1_forensic_2026_09_25/FINDING.md`):
  - The entries lack edge as standalone trades. EURUSD Test B wins 56%, but
    averages +24 pips per win against −48 per loss.
  - No TP or stop change tested reaches break-even. The untested lever is
    entry filtering (MA filter, higher-TF direction, BB width, minimum
    distance), which needs no code change.
  - **All 8 `tpsl_mode/tpsl_test_sets/*.set` use the stale
    `InpBBAppliedPrice=3` / `InpMAAppliedPrice=1`.** Corrected, Test B is
    worse (PF 0.67 → 0.60). Fixing the files changes the DCA regression
    baseline (`test_A`) as well, which is an owner decision.

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
  drawdown episode, dense parameter-cliff check, same-settings-over-time check, Monte Carlo,
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
  OOS + dense parameter-cliff + same-settings-over-time battery for AUDUSD/USDCHF/
  CADCHF (33 backtests + 3 genetic optimizations, ~11 min headless). Result:
  combined 6-symbol equity DD is **0.32%**, an improvement over the old
  7-symbol (USDCAD-included) figure of 0.77% — dropping USDCAD didn't just
  remove a risk outlier, it measurably improved the portfolio. AUDUSD/
  USDCHF/CADCHF show **zero negative windows** across 9 wider-window/OOS
  runs and 15 same-settings-over-time windows, and **zero parameter-cliffs** across 363
  dense-grid combinations (121 × 3) — nothing resembling USDCAD's risk
  profile anywhere. The batch ran on `Model=1` (1-minute OHLC) for speed.
  Full detail:
  `roboforex_study/reports/revalidation_2026_09_24/FINDING.md`.

- **2026-09-24, `Model=4` confirmation done**: re-ran the 4 most sensitive
  windows (USDCHF Full/OOS-A, AUDUSD Full, CADCHF Full) on real ticks.
  Profit came in 2-5% lower than `Model=1`; trade counts matched within 1
  and equity DD within 0.2 points. No conclusion changed, so the 6-symbol
  re-validation stands. The RoboForex workstream's validation items are
  closed; next is deployment (`CURRENT_PORTFOLIO.md` checklist) or the
  lower-priority items below.

- **Explicitly not started, and shouldn't be until the above resolves**:
  testing alternate multiplier systems (only Linear has ever been tried
  here), a wider BB parameter range (only 20-50/1.5-3.0 tested), or exit
  strategies other than BB Centre Band. Starting any of these before the
  full re-validation risks building on a foundation that just proved
  unstable once already.

### D. Repo infrastructure — migrated 2026-09-20, terminals are plain copies

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
- **2026-09-25**: session-only rules written into `CLAUDE.md` ("Session rules
  carried over"), and a paste-ready handoff prompt added at
  `prompts/SESSION_HANDOFF.md`.

### E. TRL equity logger — attached and verified 2026-09-25

The Trading Research Lab logger (`C:\DEV\Trading_Research_Lab\mql5\Include\TRL_EquityLogger.mqh`,
v1.0.1, read-only) records the floating-equity path of a single Strategy
Tester run, so TRL can import real floating drawdown alongside the report.
Rules: `CLAUDE.md` → "Session rules carried over" → TRL equity logger.

- **Built:** `TRL_EA_DCA_CENT_V1_{Logged,Control}.mq5` and
  `TRL_DCA_EA_{Logged,Control}.mq5` in `MQL5\Experts\TRL_Corpus\` on both
  terminals, made with `trl_logger/insert_trl.py`. Each Logged copy is its
  original plus exactly four `// TRL` lines (include; `TrlEquityInit()` before
  `return(INIT_SUCCEEDED)`; `TrlEquityFinish()` first in `OnDeinit`;
  `TrlEquityOnTick()` first in `OnTick`). Each Control copy is byte-identical
  to its original. The originals in `src/experts/` are untouched. All 8
  compiled with 0 errors, 0 warnings.
- **Verified:** 24 Model 4 single tests (`trl_logger/run_trl_batch.sh`):
  2 EAs × 2 terminals × 3 setups (USDCHF and EURUSD 2025.03.01–2026.03.01,
  USDCHF 2024.01.01–2026.09.19) × Control/Logged. All 12 pairs have identical
  deal lists and final balances (`trl_logger/results/comparison_2026-09-25.txt`),
  so the logger does not change trading. Each log header shows
  `trl-equity-log-1` v1.0.1. Accounts checked in the terminal logs: RoboForex
  `52010662`, FTMO `540291482`.
- **Where things are:** reports `TRL_rep_*.htm` in each terminal's root
  folder; equity logs in `%APPDATA%\MetaQuotes\Terminal\Common\Files\TRL\`
  (the FTMO ones carry a `_2` suffix). Run log:
  `trl_logger/results/batch_log_2026-09-25.txt`.
- **Combined drawdown re-measured with the logger (2026-09-25):** all 6
  deployed symbols **0.38%** ($345) on `Model=4`, vs 0.32% from the old
  bar-close method; existing 3 alone 0.61%. Each symbol's logger drawdown
  matches MT5's Equity DD Maximal within $3.28, which validates the method.
  Detail: `roboforex_study/reports/combined_dd_logger_2026_09_25/FINDING.md`.
- **Forensic EAs:** the logger now covers everything
  `EA_DCA_CENT_V1_EquityForensic.mq5` did, at finer resolution, and its
  combined-DD analysis has been redone from logger logs. It can be retired
  whenever the owner wants (it is still in the repo).
  `DCA_EA_Forensic.mq5` (signal/gate trace) and `DCA_EA_TPSL_Forensic.mq5`
  (per-position MFE/MAE) are not covered by the logger and stay.
- **Open:** import a report + log pair into TRL (Data & import → Companion
  files) — done in the TRL app by the owner, not from this repo.

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
   same-settings-over-time runs; zero parameter-cliffs across 363 dense-grid combos.
   Ran on `Model=1`; `Model=4` confirmation on the 4 most sensitive windows
   done the same day (profit 2-5% lower, conclusion unchanged). Detail:
   §2C above, `roboforex_study/reports/revalidation_2026_09_24/FINDING.md`.
6. **Deploy the 6-symbol RoboForex portfolio**: the checklist in
   `roboforex_study/CURRENT_PORTFOLIO.md` (owner's step on the live terminal).
7. ~~Attach and verify the TRL equity logger~~ — **done 2026-09-25** (§2E).
   Combined DD re-measured from logger logs the same day: 0.38% for all 6.
   Next, if wanted: import a report + log pair into TRL, and decide whether
   to retire the equity forensic EA.
8. **TP/SL mode improvement** (§2A). Phase 1 (diagnosis) is done. Needs owner
   decisions on two things:
   - whether to fix the stale price inputs in `tpsl_mode/tpsl_test_sets/`,
     which means re-baselining `test_A`;
   - phase 2 scope: TP/SL mode on the 6 portfolio symbols plus EURUSD,
     including entry-filter variants.
9. Delete the old OneDrive project folder once satisfied the new location
   works (user's own manual step, not blocking anything).
10. Lower priority, pick up whenever there's appetite: the Safe-vs-Linear
   multiplier decision (§2B), and the multiplier/BB-range/exit-strategy
   expansion for RoboForex symbols (§2C), now unblocked since the
   re-validation is done.

## 4. Where the durable rules live (not duplicated here)

`CLAUDE.md` — git discipline, the sync-to-terminals workflow, Strategy
Tester gotchas (headless config pitfalls, login drift, tick-cache
instability), and the `.set`-verification tool. Read it before any
nontrivial change, not just once at project start.
