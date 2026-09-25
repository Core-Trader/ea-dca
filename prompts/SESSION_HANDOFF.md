# Session handoff prompt — EA-DCA-V1.0

Paste everything below the line into a new Claude Code session opened at the
repo root (`C:\DEV\EA-DCA-V1.0`, or wherever this repo is cloned).

---

You are taking over work on EA-DCA-V1.0, an MQL5 DCA Expert Advisor for
MetaTrader 5 plus its validation research. The repo is the only source of
context: nothing from earlier sessions carries over except what is written in
these files.

## 1. Orient first, change nothing

Read in this order:

1. `PROJECT_HANDOFF.md`: current status, workstreams (§2), next steps (§3).
2. `CLAUDE.md`: working rules. All of it, including "Session rules carried
   over" at the end.
3. `INDEX.md`: what lives where.
4. `roboforex_study/CURRENT_PORTFOLIO.md`: the deployed symbols, their `.set`
   files, and the deployment checklist.

Then check the repo matches the handoff:
`git status -sb`, `git log --oneline -10`, `git log --oneline origin/master..master`.
If `PROJECT_HANDOFF.md`'s "Last updated" commit is behind `git log`, say so
and trust the log.

Report back briefly:
- current state of each workstream;
- work that is open, approved-but-not-done, or deferred;
- anything waiting on the owner (decisions, manual steps, reviews);
- the next step you propose.

Then wait. Change nothing until the owner confirms.

## 2. Git

- Branch `master`, remote `origin`. Don't create or switch branches unless asked.
- Never change `git config user.name` / `user.email`.
- Commit after each meaningful, verified unit of work. Match the log's style:
  imperative subject (optional area prefix like `CLAUDE.md: `), then a body
  explaining why. End with the attribution trailers your harness provides
  for this session.
- Push only when the owner explicitly asks. The pre-push check and the
  failure rule are in `CLAUDE.md` → "Git discipline".
- Never commit `.ex5`/`.ex4`, TRL equity logs, or anything `.gitignore`
  excludes. Stage files by name, not `git add -A`.
- No force-push, amend, reset or rebase unless asked for that action.
- If any git step fails, report the exact error and stop.

## 3. How work is done here

- **Approval gates:** ask before every backtest run or batch (`CLAUDE.md` →
  "Strategy Tester"), and before anything irreversible or visible to others.
  Exploratory questions get a recommendation, not action.
- **After any change to `src/experts/` or `src/indicators/`:** run
  `scripts/sync_to_terminals.ps1`, then compile through the terminal's
  portable MetaEditor. A compile with 0 errors is the minimum check (there is
  no test suite or CI).
- **Before a new study or baseline `.set`:** run
  `py scripts/verify_set_against_defaults.py <ea.mq5> <file.set>` and review
  every difference.
- **Backtests:** follow `CLAUDE.md` → "Strategy Tester" exactly. Check
  `Get-Process terminal64` first; never close the owner's terminal. Trust a
  result only after checking the report's Settings section (symbol, dates,
  key inputs) and the authorised account.
- **Record results** in the relevant study file (e.g. a `FINDING.md` beside
  the raw reports), then in `PROJECT_HANDOFF.md`.
- **Report verification explicitly:** say what was checked, how, and what
  was not checked.

## 4. Safety, privacy and sourcing

All rules are in `CLAUDE.md`. Pay particular attention to "Session rules
carried over", which covers:
- the live terminal;
- Model 1 vs Model 4;
- background batches;
- methodology wording (not "walk-forward"; reordering vs bootstrap);
- unsourced thresholds;
- the TRL equity logger's read-only and `TRL_`-prefix rules.

Don't put account passwords, server credentials or account data anywhere in
the repo.

## 5. Communication

English, short and plain. Lead with the result or the decision needed.
Complete sentences, no jargon without a gloss. Keep final summaries to a few
lines, plus tables when there are numbers to compare.

## 6. Before ending, or when context runs low

1. Update `PROJECT_HANDOFF.md`:
   - "Last updated" line;
   - the affected workstream in §2 (what changed, what was verified and how);
   - §3 next steps.
2. If a new durable rule was agreed, add it to `CLAUDE.md`.
3. Commit those updates with the rest of the work.
4. Push only if the owner has asked.
5. Tell the owner the commit hash, and whether it was pushed.
