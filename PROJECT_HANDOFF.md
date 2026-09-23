# EA-DCA-V1.0 — Project Handoff

**Last updated**: 2026-09-20, as of commit `7ed93c3`.

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

### C. RoboForex multi-symbol study — portfolio defined, ⚠ pending re-validation

- Real funded cent account (RoboForex-Pro, Login `52010662`). Screened the
  full Market Watch universe for portfolio-diversification candidates,
  landed on a 7-symbol portfolio: EURUSD/GBPUSD/USDJPY (existing) +
  AUDUSD/USDCHF/USDCAD/CADCHF (Tier 1 candidates). Full validation backlog
  completed — wider-window/OOS, trade-level investigation of a USDCAD
  drawdown episode, dense parameter-cliff check, walk-forward, Monte Carlo,
  USDCHF/CADCHF co-dependency check. All findings and reasoning:
  `roboforex_study/SYMBOL_SCREENING_REPORT.md`. Live-facing summary:
  `roboforex_study/CURRENT_PORTFOLIO.md`.

- **⚠ CRITICAL, found 2026-09-20**: `InpBBAppliedPrice` was wrong
  (`3`/PRICE_LOW instead of the EA's actual default, `2`/PRICE_HIGH)
  throughout the **entire study** — traced to a stale reference `.set` file
  used when the study was set up, predating an earlier fix to the EA's own
  compiled default. Confirmed via an actual generated report's own Settings
  section, not just the `.set` file on disk. **Fixed in all 13 source `.set`
  files** (`roboforex_study/sets/`), but **not yet re-validated** — every
  finding in `SYMBOL_SCREENING_REPORT.md`/`CURRENT_PORTFOLIO.md` (the Tier 1
  picks, the USDCAD risk profile, all of it) was derived under the wrong
  price basis and is marked **provisional** in both documents' own top-of-
  file warnings until re-run.

- **Immediate next action, in progress**: user is running
  `roboforex_study/BACKTEST_VIABILITY_CHECKLIST.md` manually (usage-budget
  constrained — this doesn't need Claude Code credits) to spot-check
  whether the corrected price basis changes the picture a little or a lot,
  before deciding whether the full OOS/walk-forward/Monte Carlo battery
  needs repeating. **When those 7 numbers come back, update this section
  and the two reports' warning banners** — don't leave them generically
  "provisional" once there's an actual answer.

- **Explicitly not started, and shouldn't be until the above resolves**:
  testing alternate multiplier systems (only Linear has ever been tried
  here), a wider BB parameter range (only 20-50/1.5-3.0 tested), or exit
  strategies other than BB Centre Band. Starting any of these before the
  price-basis re-validation risks building on the same stale foundation
  twice — see the forensic audit discussion that established this
  sequencing.

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

1. **Get the §2C checklist results back** and update the provisional
   warnings in `SYMBOL_SCREENING_REPORT.md`/`CURRENT_PORTFOLIO.md` (and this
   file) with the actual outcome.
2. Based on #1, decide whether the RoboForex portfolio's full validation
   stack (OOS, walk-forward, Monte Carlo) needs repeating, or whether a
   spot-check confirms the existing conclusions still hold.
3. Delete the old OneDrive project folder once satisfied the new location
   works (user's own manual step, not blocking anything).
4. Lower priority, pick up whenever there's appetite: the Safe-vs-Linear
   multiplier decision (§2B), porting TP/SL mode into `EA_DCA_CENT_V1.mq5`
   (§2A), and the explicitly-deferred multiplier/BB-range/exit-strategy
   expansion for RoboForex symbols (§2C).

## 4. Where the durable rules live (not duplicated here)

`CLAUDE.md` — git discipline, the sync-to-terminals workflow, Strategy
Tester gotchas (headless config pitfalls, login drift, tick-cache
instability), and the `.set`-verification tool. Read it before any
nontrivial change, not just once at project start.
