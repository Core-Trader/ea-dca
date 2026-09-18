# EA-DCA-V1.0 — Working Rules

## Git discipline (non-negotiable)

This project's `src/experts/` and `src/indicators/` folders are symlinked into a
live, shared MetaTrader 5 environment (`MQL5\Experts\EA-DCA-V1.0` and
`MQL5\Indicators\EA-DCA-V1.0`) that other AI tools and manual MetaEditor edits
also touch. Changes made outside this repo's own workflow land directly in
these tracked files with no warning. Git history is the only real safety net
against silently losing or overwriting work — treat it accordingly:

- **Commit after every meaningful unit of work** — a completed build phase, a
  bug fix, a refactor, a resolved design decision. Do not let more than one
  logical unit of work sit uncommitted. A long session with zero commits until
  the very end is exactly the failure mode this file exists to prevent.
- **Check `git status` and `git diff` before starting a significant edit**,
  especially to anything under `src/experts/` or `src/indicators/` — those
  files can drift from outside this session (see above). If something
  unexpected shows up, surface it to the user before folding it into a
  commit; don't silently absorb someone else's change into your own.
- **Never** force-push, `reset --hard`, amend a commit, or run any other
  history-rewriting command without the user explicitly asking for that
  specific action in that specific moment. Always create a new commit rather
  than amending.
- Write commit messages that describe *why*, and name the phase/milestone
  when relevant (e.g. "Phase 3: exit strategies, Dynamic Stop, Partial
  Close, Risk Reduction, Recovery Mode") — they double as the project's
  changelog and its rollback points.
- Only commit when asked, per Claude Code's general default — but for this
  project, "proceed with phase N" or "build X" from the user is itself the
  request to commit that unit of work once it's done and verified (compiles
  clean at minimum), not a separate ask each time.

## Compiled artifacts

Never commit `.ex5`/`.ex4` binaries — only `.mq5` source. The repo-root
`.gitignore` covers this for the whole tree (not just `src/experts/`), since
compiled indicators under `src/indicators/` are just as easy to accidentally
stage as the EA itself.

## Compiling

MetaEditor resolves standard-library `#include`s (e.g. `<Trade\Trade.mqh>`)
from one fixed shared terminal folder, not from wherever the source file
lives. Always compile through the actual portable install:

```
"C:\FTMO Global Markets MT5 Terminal\MetaEditor64.exe" /portable /compile:"C:\FTMO Global Markets MT5 Terminal\MQL5\Experts\EA-DCA-V1.0\DCA_EA.mq5" /log:"<logfile>"
```

## Strategy Tester

**Always ask the user first — every time — whether they want you to run a**
**backtest yourself or run it manually and share the results.** This applies
to every backtest and diagnostic run, not just the first one in a session;
don't assume standing permission from an earlier "yes" in the same
conversation carries forward to the next run.

`terminal64.exe /portable /config:"<ini>"` runs a headless backtest — but:

- **Close the live terminal first.** MT5 allows only one instance per data
  folder; if the terminal is already open, a second headless launch silently
  does nothing (exits fast, no report, no error). Check
  `Get-Process -Name terminal64` before launching, and ask the user before
  closing anything they have open.
- **Always pass `ExpertParameters=<bare filename>.set` explicitly**, with the
  `.set` file copied into `MQL5\Profiles\Tester\` first — not an absolute
  path. With no `ExpertParameters`, or with an absolute path (confirmed to
  silently fail too, not just an omitted value), the Tester silently reuses
  whatever `.set` was last associated with an Expert of that exact name — and
  this project's `MQL5\Profiles\Tester\` folder has many stale presets from
  prior test iterations (this project's own history and other AI-assisted
  variants sharing the same environment). It will NOT fall back to the
  `.mq5`'s compiled-in defaults. Verify the report's Settings section
  actually shows the intended parameter values before trusting any result.
- **Use `Model=4` ("Every tick based on real ticks"), not `Model=1`.**
  Confirmed this session: this EA's touch-mode exits read live bid/ask every
  tick, so `Model=1`'s synthetic intrabar tick path produces a materially
  different trade history than the reference reports (and than manual GUI
  runs) from the same `.set`. `Model=4` was confirmed to exactly reproduce a
  manual GUI run's deal log down to the second across 113 deals. `Model=4`
  headless runs work fine in this environment (no hang) — the historical
  "Cloud servers switched off" hang was NOT a `Model=4`-specific issue (see
  below).
- **Pass the `/config:"<ini>"` path as a literal Windows backslash path**
  (`C:\Users\...\file.ini`), not a bash-style forward-slash path (even via a
  shell variable like `$SCRATCH/file.ini`, which itself contains
  forward-slash segments once expanded). Confirmed this session: a
  forward-slash path embedded in the combined `/config:"..."` flag does not
  get translated the way a standalone argument would, so `terminal64.exe`
  silently ignores it — no error, but it also doesn't run your intended
  config. Symptom is confusing: the terminal can still complete some
  *leftover/stale* simulation (a real "Test passed" + final balance appears
  in the log) without ever loading your `.set`/`Report=` name, so a report
  file under your intended name never appears, even though the log looks
  superficially like a successful run. **Always verify the report file was
  actually created under the name you passed** (`Report=` in the `.ini`)
  before trusting any result — don't infer success from the log alone.
- **"Cloud servers switched off" in the log is benign, not a failure.** It's
  followed immediately by "cloud network mode is off" and the run proceeding
  normally on local agents — this appears on essentially every headless run
  in this environment (even ones that complete and write their report
  correctly) and is not diagnostic of anything going wrong.
- **If `Login=` in the `.ini` stops taking effect on a terminal that previously
  worked reliably** (the run silently authorizes as a *different* account than
  specified, confirmed in the log's own `authorized on <server>` line — this can
  happen even with an explicit `Server=` override added to the `[Tester]`
  section too), the terminal's own locally-stored account list has likely
  picked up a stray account from a different project/terminal at some point
  (e.g. a `.ini` accidentally launched against the wrong terminal executable)
  and that account has become the cached default. Fix: open the terminal's
  GUI and delete the stray account from its stored account list — this project
  hit exactly this on 2026-09-18 (a RoboForex account had gotten saved into
  the FTMO terminal's own profile). **Always verify the report's own log shows
  the intended account authorized, the same way you verify the Settings
  section** — a wrong-account run still produces a normal-looking "successfully
  finished" report with a real (just wrong) dataset behind it.
- Working reference `.ini` (adjust `Expert`/`ExpertParameters`/`Report`/dates
  per run):
  ```
  [Tester]
  Login=540291482
  Expert=EA-DCA-V1.0\DCA_EA
  ExpertParameters=<bare filename>.set
  Symbol=EURUSD
  Period=H4
  Model=4
  Optimization=0
  FromDate=2025.01.01
  ToDate=2026.01.22
  ForwardMode=0
  Deposit=100000
  Currency=USD
  Leverage=30
  ExecutionMode=0
  Report=<report name>
  ReplaceReport=1
  ShutdownTerminal=1
  Visual=0
  ```
  Launch with: `"C:\FTMO Global Markets MT5 Terminal\terminal64.exe" /portable /config:"C:\<windows-style path>\<name>.ini"` — run in the foreground (no `&`, no
  `run_in_background`) so the tool call actually waits for completion instead
  of returning as soon as the process is merely launched.
