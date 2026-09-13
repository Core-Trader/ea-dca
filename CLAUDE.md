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

`terminal64.exe /portable /config:"<ini>"` runs a headless backtest — but:

- **Close the live terminal first.** MT5 allows only one instance per data
  folder; if the terminal is already open, a second headless launch silently
  does nothing (exits fast, no report, no error). Check
  `Get-Process -Name terminal64` before launching, and ask the user before
  closing anything they have open.
- **Always pass `ExpertParameters=<path to a .set file>` explicitly.** With
  no `ExpertParameters`, the Tester silently reuses whatever `.set` was last
  associated with an Expert of that exact name — and this project's
  `MQL5\Profiles\Tester\` folder has many stale presets from prior test
  iterations (this project's own history and other AI-assisted variants
  sharing the same environment). It will NOT fall back to the `.mq5`'s
  compiled-in defaults. Verify the report's Settings section actually shows
  the intended parameter values before trusting any result.
