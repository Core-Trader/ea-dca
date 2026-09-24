# EA-DCA-V1.0 — Working Rules

> These are the durable *rules* for working in this repo. For current
> *status* — what's done, what's decided, what's still open — read
> `PROJECT_HANDOFF.md` first, and keep it updated when that status changes.

## Git discipline (non-negotiable)

**As of 2026-09-20**, `src/experts/` and `src/indicators/` are **plain,
independently-maintained copies** on both the FTMO and RoboForex terminals —
`scripts/sync_to_terminals.ps1` pushes source out to both after any change
(see "Sync to terminals" below). This replaced an earlier live-symlink setup
on the FTMO terminal specifically, deliberately, to match RoboForex's own
already-established plain-copy convention. Because it's now a manual push
rather than an automatic link, the risk direction is the opposite of what it
used to be: **a terminal's copy can silently go stale** if a source change
isn't synced, rather than an outside edit silently landing in the repo. Git
history remains the safety net either way — treat it accordingly:

- **Commit after every meaningful unit of work** — a completed build phase, a
  bug fix, a refactor, a resolved design decision. Do not let more than one
  logical unit of work sit uncommitted. A long session with zero commits until
  the very end is exactly the failure mode this file exists to prevent.
- **Check `git status` and `git diff` before starting a significant edit** —
  the repo itself is no longer symlink-exposed to outside edits (see above),
  but if a manual MetaEditor session or another AI tool ever does edit a file
  directly under this path, the same rule applies: surface it to the user
  before folding it into a commit, don't silently absorb someone else's
  change into your own.
- **After any change to `src/experts/` or `src/indicators/`, run
  `scripts\sync_to_terminals.ps1` before compiling or backtesting on either
  terminal** — neither one reads from the repo automatically anymore. This is
  the new failure mode to watch for, replacing the old symlink-drift one: a
  terminal silently running stale code because the push step was skipped.
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

## Verify a new study's "default" `.set` before running anything on it

**Found 2026-09-20**: an entire RoboForex study (~40+ backtests, its whole
Tier-1-candidate/portfolio conclusion) was built on a `.set` file
(`strategyA_bb_default.set`) copied from an old reference
(`diagnostics/backtests/cent_v1_baseline/EA_DCA_CENT_V1_baseline.set`) that
predated a later fix to the EA's own compiled default (`InpBBAppliedPrice`,
commits `5e80cc8`/`7db75df`/`50ea428`). Nothing caught the mismatch until the
user spotted it independently — by then it had propagated into 13 different
`.set` files across the whole study.

**Before starting a new study, or building a new "default" `.set` from any
existing reference file, run:**
```
python scripts/verify_set_against_defaults.py <path-to-ea.mq5> <path-to-new.set>
```
This diffs every field in the `.set` against the EA's own compiled `input`
defaults (parsed directly from the `.mq5` source, resolving custom and
common native enums to their integer values) and prints every difference —
it does not judge which differences are intentional (e.g. a deliberately
lower `InpMaxSequencesPerDirection` for cent-account risk control is fine),
it just makes every one of them **visible** so a human/AI consciously
accepts or rejects each one, instead of silently inheriting whatever an old
copy-pasted reference file happened to contain. Exits non-zero if anything
differs — treat that as informational, not necessarily a failure, but never
skip reading the output.

Re-run it any time a `.set` file that serves as a study's baseline is
created or copied from an older one, not just once at project start.

## Sync to terminals — nothing is symlinked, everything is a manual push

**As of 2026-09-20, both the FTMO and RoboForex terminals are plain, manually-synced
copies of this repo's `src/` — there is no symlink anywhere in this project any
more.** (The FTMO terminal used to be symlinked; it was deliberately converted to a
plain copy to match RoboForex's own long-standing convention and remove the
directory-symlink fragility that came with moving the repo itself.) Run
```
powershell -File scripts\sync_to_terminals.ps1
```
after **any** change to `src/experts/` or `src/indicators/`, before compiling or
backtesting on either terminal. It copies `.mq5` source only (never `.ex5` —
each terminal compiles its own binary locally) to four destinations per terminal:
the `EA-DCA-V1.0` subfolder under both `Experts\` and `Indicators\`, plus two of the
three indicators' **bare-named root-level copies** (see below). Skipping this step
means a terminal silently keeps running whatever it last had — no error, no warning.

### The root-level indicator copies specifically

`DCA_EA.mq5`/`EA_DCA_CENT_V1.mq5` load `QMP Filter`, `QQE Adv`, and (via QMP Filter
internally) `MACD_Platinum` via `iCustom(_Symbol, tf, "QMP Filter", ...)` with a bare
name. MT5 resolves a bare `iCustom()` name against the **root** of `MQL5\Indicators\`,
not recursively into the `EA-DCA-V1.0` subfolder — confirmed on the RoboForex terminal
(`go_live/GO_LIVE_VALIDATION_PLAN.md` §5.4) and reconfirmed 2026-09-19. So each terminal
needs a **second, separate copy** of these three files sitting directly at
`MQL5\Indicators\` root (space-containing names for two of them — `QMP Filter.mq5`,
`QQE Adv.mq5`; `MACD_Platinum.mq5` keeps its underscore even at root — all three
matching the exact `iCustom()` call strings), independent of the `EA-DCA-V1.0\`
subfolder copies (repo's own underscore names — `QMP_Filter.mq5`, `QQE_Adv.mq5`).
`sync_to_terminals.ps1` handles this renaming automatically; don't assume a plain
subfolder copy alone covers indicator changes.

Confirmed drifted in practice before the sync script existed: the FTMO terminal's
root-level `QQE Adv.mq5` had different default `input` values (`SF`/`RSI_Period`/`WP`)
than the repo-tracked `QQE_Adv.mq5` — benign only because the EA always passes its own
`.set`-driven parameters explicitly to every `iCustom()` call, so the indicator's own
compiled-in defaults are never actually read; a future drift in the indicator's
*calculation logic* (not just its defaults) would not be so harmless.

**`BB.mq5` does NOT need a root-level copy** — the EA uses the native `iBands()`
function for Bollinger Bands, not `iCustom()`; `BB.mq5` in `src/indicators/` is unused
reference material, not a live dependency.

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
  `Get-Process -Name terminal64` before launching (a Windows-level check —
  Git Bash's `ps` misses terminals the user opened; see the `pgrep` bullet
  below), and ask the user before closing anything they have open.
- **Always pass `ExpertParameters=<bare filename>.set` explicitly**, with the
  `.set` file copied into `MQL5\Profiles\Tester\` first — not an absolute
  path. With no `ExpertParameters`, or with an absolute path (confirmed to
  silently fail too, not just an omitted value), the Tester silently reuses
  whatever `.set` was last associated with an Expert of that exact name — and
  this project's `MQL5\Profiles\Tester\` folder has many stale presets from
  prior test iterations (this project's own history and other AI-assisted
  variants sharing the same environment). It will NOT fall back to the
  `.mq5`'s compiled-in defaults in that case. Verify the report's Settings
  section actually shows the intended parameter values before trusting any
  result.
- **A THIRD, distinct failure mode: if the bare filename passed to
  `ExpertParameters=` no longer exists in `MQL5\Profiles\Tester\`** (e.g. it
  was copied there in an earlier session and has since been removed/never
  re-copied — that folder is not guaranteed to still hold every `.set` you've
  ever used), the Tester does NOT error and does NOT reuse a stale `.set`
  either — it silently runs with the `.mq5`'s raw **compiled-in defaults**.
  Confirmed 2026-09-19: `EA_DCA_CENT_V1.mq5` produced a completely
  normal-looking "successfully finished" report at exactly its plain
  DCA-mode baseline numbers when the intended TP/SL `.set` file had fallen
  out of that folder — no error, no warning, values simply reverted to
  whatever `input` defaults are hardcoded in the source. Same rule applies:
  verify the report's Settings section shows the intended values, and
  additionally confirm the `.set` file you intend to reference is actually
  present in `MQL5\Profiles\Tester\` *right now*, not just "was copied there
  earlier this project."
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
  **Reconfirmed 2026-09-19, a MIXED path is just as broken as a pure
  forward-slash one**: building the config argument as
  `"$SCRATCH/$name.ini"` in a bash loop — where `$SCRATCH` itself is a
  correct Windows backslash path (`C:\Users\...\claude`) but gets joined to
  the filename with a literal `/` — reproduces the exact same silent
  failure. The terminal launches, authorizes, and idles with **no** Tester/
  AutoTesting activity at all (worse than the stale-simulation symptom
  above — this time nothing runs, not even something old), and the log's
  own `Terminal: launched with ...` line shows the giveaway: it prints only
  up to the last all-backslash segment (e.g. `launched with
  C:\Users\vasco\AppData\Local\Temp\claude`, filename silently dropped) —
  **check that this exact log line includes your full intended filename**
  before assuming a launch worked, not just that `terminal64.exe` returned
  or that the process is running. Build the whole config path as one
  literal, fully-backslash string (no shell-side path joining with `/` at
  all, even for one segment) — e.g. write out each `.ini`'s full path
  explicitly rather than concatenating a variable with a `/`.
  **Also**: if you kill a `terminal64.exe` that was launched from inside a
  still-running shell loop (e.g. via `run_in_background`), the loop's next
  iteration will immediately relaunch a new instance — this can look
  exactly like unexplained "auto-restart" behavior (new PID appears within
  seconds no matter how the old one was terminated) and wastes time being
  investigated as a Windows/MT5 crash-recovery mechanism. Before chasing
  that theory, check whether one of your own background tasks is still
  mid-loop and simply launching the next iteration.
- **`pgrep` does not exist in this project's Bash tool environment (Git
  Bash/MSYS) — it returns `command not found`, exit 127.** Confirmed
  2026-09-19: a wait-loop written as `while pgrep -f "terminal64.exe" >
  /dev/null 2>&1; do sleep 10; done` before each sequential launch in a
  multi-job batch silently did **nothing** — a nonexistent command exits
  127 (non-zero → "false"), so the loop treated "terminal still running" as
  immediately false every time and launched the next job with **zero**
  actual waiting. Since MT5 allows only one instance and a second launch
  while one is already open silently no-ops (see above), this meant only
  the *first* job in a 6-job batch actually ran — the other 5 each fired
  into an already-busy terminal and did nothing, producing no report and no
  error either. **Check at the Windows level with `Get-Process`, never with
  `ps`.** From PowerShell: `Get-Process -Name terminal64 -ErrorAction
  SilentlyContinue`. From Git Bash (exits 0 while a terminal is running,
  so it works directly as a `while` wait-loop condition):
  ```
  powershell -NoProfile -Command "exit [int](-not (Get-Process terminal64 -ErrorAction SilentlyContinue))"
  ```
  Don't use `ps aux | grep terminal64` — this file used to recommend it.
  Confirmed 2026-09-24: in Git Bash, `ps` only lists processes started from
  inside the MSYS shell, so a terminal the user opened normally from Windows
  is invisible to it. The check reported "clear" while the user's live
  RoboForex terminal was open, and all 4 queued headless launches silently
  no-oped against it. Whenever chaining sequential headless launches,
  verify the wait mechanism actually blocks (e.g. by checking elapsed time
  or watching the log advance) rather than trusting that a loop "looks
  right" — an always-false condition produces no error, just silent,
  instant fall-through.
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
