# EA-DCA-V1.0

A MetaTrader 5 Expert Advisor that trades Bollinger Band / QQE signals with a
DCA (dollar-cost-averaging) position ladder, plus an optional single-position
TP/SL mode. This repo also holds the research used to take it toward a live
cent account: go-live validation, a multi-symbol screening study, and the
backtest reports behind each conclusion.

## Start here

| Read | For |
| --- | --- |
| [`PROJECT_HANDOFF.md`](PROJECT_HANDOFF.md) | Current status: what's done, what's decided, what's open, what's next |
| [`CLAUDE.md`](CLAUDE.md) | Working rules: git discipline, compiling, terminal sync, Strategy Tester gotchas |
| [`INDEX.md`](INDEX.md) | Full map of the repo, folder by folder |
| [`roboforex_study/CURRENT_PORTFOLIO.md`](roboforex_study/CURRENT_PORTFOLIO.md) | The symbols and `.set` files currently intended for the cent account |

## What's in the repo

| Path | Contents |
| --- | --- |
| `src/experts/` | `DCA_EA.mq5` (development EA), `EA_DCA_CENT_V1.mq5` (frozen cent-account baseline), and read-only forensic/diagnostic variants |
| `src/indicators/` | Custom indicators the EA loads (`QMP_Filter`, `QQE_Adv`, `MACD_Platinum`) plus unused reference `BB.mq5` |
| `docs/` | Original functional specification (`.docx`) |
| `reports/` | Reports from the original build and validation |
| `go_live/` | Go-live validation plan and audit trail |
| `tpsl_mode/` | TP/SL mode design audit, root-cause work, and test `.set` files |
| `roboforex_study/` | Multi-symbol screening study, portfolio `.set` files, raw backtest output and analysis scripts |
| `scripts/` | `verify_set_against_defaults.py` and `sync_to_terminals.ps1` |

## Requirements

- MetaTrader 5 terminal with MetaEditor, installed in portable mode.
- Python 3, only for the analysis scripts under `scripts/` and `roboforex_study/reports/`.
- PowerShell, for `scripts/sync_to_terminals.ps1`.

## Workflow

1. **Edit** the `.mq5` source under `src/`. New features and fixes go into
   `DCA_EA.mq5` first. `EA_DCA_CENT_V1.mq5` is only ever re-baselined from it,
   never hand-edited.
2. **Sync** to the terminals. They hold plain copies of `src/` and don't read
   the repo directly:
   ```
   powershell -File scripts\sync_to_terminals.ps1
   ```
3. **Compile** through the terminal's own portable MetaEditor, so standard
   library includes resolve:
   ```
   "<terminal>\MetaEditor64.exe" /portable /compile:"<terminal>\MQL5\Experts\EA-DCA-V1.0\DCA_EA.mq5" /log:"<logfile>"
   ```
4. **Check the `.set` file** before starting a new study or baseline. This
   lists every value that differs from the EA's compiled defaults:
   ```
   python scripts/verify_set_against_defaults.py src/experts/EA_DCA_CENT_V1.mq5 <path-to.set>
   ```
5. **Backtest** with Model "Every tick based on real ticks". Before trusting a
   report, confirm its Settings section shows the symbol, dates and inputs you
   intended. `CLAUDE.md` lists the ways headless runs can fail without any
   error.

## Conventions

- Never commit compiled `.ex5` / `.ex4` binaries; `.gitignore` excludes them.
- Commit after each meaningful unit of work, and explain why in the message.
- Keep `PROJECT_HANDOFF.md` current whenever a status or decision changes.
