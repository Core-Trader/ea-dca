# EA-DCA-V1.0 — Repository Index

A Bollinger-Band/QQE-driven DCA (dollar-cost-averaging) MetaTrader 5 Expert
Advisor, its cent-account variant, a TP/SL single-position trading mode, and
the go-live/multi-symbol research built around them. **Start with
`CLAUDE.md`** for the non-negotiable working rules (git discipline, compiling,
Strategy Tester gotchas) before touching anything here — this file is a map,
not a replacement for it.

## Source code — `src/`

| Path | What it is |
|---|---|
| `src/experts/DCA_EA.mq5` | The core development EA — DCA mode + TP/SL mode, all ongoing feature work lands here first |
| `src/experts/EA_DCA_CENT_V1.mq5` | Frozen cent-account go-live baseline, deliberately re-baselined from `DCA_EA.mq5` (never hand-edited directly — see its own header) |
| `src/experts/EA_DCA_CENT_V1_EquityForensic.mq5` | Pure-read diagnostic copy of `EA_DCA_CENT_V1.mq5` — logs per-bar Balance/Equity/floating-profit to CSV, used for drawdown-timing investigations |
| `src/experts/DCA_EA_Forensic.mq5` | Pure-read diagnostic copy of `DCA_EA.mq5` for DCA-mode forensic trade analysis |
| `src/experts/DCA_EA_TPSL_Forensic.mq5` | Pure-read diagnostic copy with per-position MFE/MAE logging, for TP/SL-mode trade analysis |
| `src/experts/DCA_EA_V1.mq5` / `_V2.mq5` / `_V3.mq5` | Earlier build-phase snapshots, kept for history |
| `src/indicators/` | `QMP_Filter.mq5` (entry dots), `QQE_Adv.mq5`, `MACD_Platinum.mq5`, `BB.mq5` — supporting custom indicators |

Compiled `.ex5` binaries are never committed (`.gitignore`) — this folder is
symlinked into the live MT5 terminal(s), so `git status`/`git diff` here can
reflect changes made outside this repo's own workflow; check before editing.

## Documentation — `docs/`

`EA User Guide.docx`, `DCA EA Walkthrough.docx` — the original functional
specification this EA was built from.

## Reference — `reference/`

`_0_JFX_DCA_Type_V_v1_Money.mq5` — a reference EA's source (transcript-derived
functional description only; no code from the commercial product has ever
been inspected or copied — see this project's own standing policy). The
compiled `.ex5` sibling is gitignored, kept locally only.

## Historical development reports — `reports/`

Chronological audit/root-cause reports from the EA's original build-out and
validation against the reference EA, before the go-live and TP/SL tracks
below existed:

| File | Covers |
|---|---|
| `DCA_EA_Analysis_Report.md` | Original functional spec analysis the EA was built from |
| `DCA_EA_AUDIT_REPORT.md` | Code audit against that spec |
| `DCA_EA_DOCS_AUDIT_REPORT.md` | Audit against the `docs/` user guide specifically |
| `FORENSIC_COMPARISON_REPORT.md` | Trade-by-trade comparison against the reference EA's own behavior |
| `DCA_EA_ENTRY_EXIT_DIVERGENCE_REPORT.md` | Investigation into entry/exit timing divergence found during that comparison |
| `PNL_DISCREPANCY_ROOT_CAUSE_REPORT.md` | Root-cause of a PnL mismatch found during validation (Finding 2, referenced elsewhere as the login-drift/bar-close-vs-live-tick fix) |
| `VISUAL_TEST_2025_DIAGNOSTIC_REPORT.md` | Diagnostic tied to `diagnostics/backtests/Visual_test_2025*.xlsx` |

## Go-live validation — `go_live/`

`GO_LIVE_VALIDATION_PLAN.md` — the central, numbered go-live audit trail for
deploying the DCA track toward a RoboForex cent account: environment audit,
cent-account risk categorization, baseline backtests, sensitivity sweeps,
Monte Carlo, circuit-breaker design, genetic optimization, OOS validation.
Standing principles worth knowing before reading it: optimize for robustness
not historical profit, don't assume backtest performance transfers to live,
don't assume a cent account just has 100x the balance, never hide a poor
result.

## TP/SL trading mode — `tpsl_mode/`

A second, single-position (non-averaging) trade-management mode added
alongside the original DCA mode, with 7 stop-loss methods and a Balance-%
take-profit exit.

| Path | What it is |
|---|---|
| `TPSL_MODE_AUDIT.md` | Feasibility audit, compatibility matrix, and the mandatory Implemented/Tested/Not-yet-tested status table for every SL type and exit strategy |
| `TPSL_EQUITY_BALANCE_ROOT_CAUSE.md` | Root-cause investigation into a declining-Balance / Equity-above-Balance divergence found in TP/SL mode backtests, and the fixes that came out of it |
| `tpsl_test_sets/` | The `.set` files used to validate each SL type/exit combination (`test_A` through `test_J`) |

## RoboForex multi-symbol study — `roboforex_study/`

Self-contained: real funded cent account (RoboForex-Pro), BB/QQE parameter
optimization across the original 3-symbol portfolio, then a full symbol
screening pass across Market Watch to find portfolio-diversification
candidates.

| File | What it is |
|---|---|
| `ROBOFOREX_MULTI_SYMBOL_STUDY.md` | BB/QQE optimization grids for the original EURUSD/GBPUSD/USDJPY portfolio at the account's real $15,000 deposit |
| `SYMBOL_SCREENING_REPORT.md` | The full diversification screening study — Market Watch-wide default-parameter pass, genetic optimization shortlist, correlation/drawdown-overlap analysis, wider-window/OOS validation, trade-level investigation, dense parameter-cliff check, walk-forward, Monte Carlo, and the resulting Tier 1 candidate picks (AUDUSD/USDCHF/USDCAD/CADCHF) |
| `CURRENT_PORTFOLIO.md` | **The live-facing summary** — the current 7-symbol portfolio, what's deliberately different from the tested configuration (per-symbol magic numbers) and why, and the deployment checklist |
| `sets/cent_portfolio/<SYMBOL>.set` | The actual `.set` file to load per symbol for the current portfolio |
| `sets/*.set` | Other named configs used across the study (defaults, optimization sweep definitions) |
| `reports/*/` | Raw backtest/optimization output (XML/HTM/CSV) and the Python analysis scripts, one subfolder per study phase — kept for reproducibility, not meant to be read directly unless verifying a specific number |

## Everything else

- `default.set` — the original baseline `.set` for `DCA_EA.mq5`, matches the
  input order in `DCA_EA_Analysis_Report.md`.
- `diagnostics/backtests/` — gitignored scratch space for backtest reports
  generated during development; not version-controlled, may be empty or
  stale at any given time.
- `.claude/` — Claude Code project-local configuration.

## Finding things by topic, not by folder

- **"Why does the EA behave like X in DCA mode?"** → `reports/` (original
  build) or `go_live/GO_LIVE_VALIDATION_PLAN.md` (later go-live-specific
  findings).
- **"How does TP/SL mode's stop-loss/exit logic work, and what's tested?"**
  → `tpsl_mode/TPSL_MODE_AUDIT.md`.
- **"Why did Balance/Equity diverge in a backtest?"** → the general
  mechanism was first fully diagnosed in `tpsl_mode/TPSL_EQUITY_BALANCE_ROOT_CAUSE.md`
  and has since recurred (and been separately confirmed) for USDJPY and
  USDCAD in `roboforex_study/SYMBOL_SCREENING_REPORT.md`.
- **"What symbols are we trading on the cent account, and why?"** →
  `roboforex_study/CURRENT_PORTFOLIO.md`.
- **"Has &lt;symbol&gt; been robustness-tested, and how?"** →
  `roboforex_study/SYMBOL_SCREENING_REPORT.md`.
- **"What are the Strategy Tester gotchas in this environment?"** →
  `CLAUDE.md` (always check this before running any backtest).
