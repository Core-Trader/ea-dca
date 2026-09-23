# Manual Backtest Checklist — Post-Fix Portfolio Viability Check

**Purpose**: re-run the 7 portfolio symbols with the corrected `InpBBAppliedPrice=2`
(PRICE_HIGH — see `CURRENT_PORTFOLIO.md`'s warning banner for the full incident)
and check whether each symbol still looks viable, before spending any further
budget re-running the full validation stack (OOS, walk-forward, Monte Carlo).
This is the cheap, first-pass check: **one window, one run per symbol.**

Do this manually in the MT5 GUI — no Claude Code / API budget needed.

---

## 0. One-time setup

- [ ] Close the live RoboForex terminal if it's open (only one instance per
      data folder can run the Tester).
- [ ] Confirm the `.set` files are the corrected ones: open
      `roboforex_study/sets/cent_portfolio/EURUSD.set` in a text editor and
      check it says `InpBBAppliedPrice=2` (not `3`). If you want to be
      thorough, run the new checker against all 7 first:
      ```
      python scripts/verify_set_against_defaults.py src/experts/EA_DCA_CENT_V1.mq5 roboforex_study/sets/cent_portfolio/*.set
      ```
      Expect exactly one reported difference per file
      (`InpMaxSequencesPerDirection: compiled_default=100 set_file=3`) — that
      one's deliberate (cent-account risk cap), not a bug. Anything else
      showing up is new and worth pausing on before proceeding.
- [ ] Make sure each `.set` is copied into
      `MQL5\Profiles\Tester\` on the RoboForex terminal (if you last used
      them there, they should already be present — check the folder).

## 1. Per-symbol Strategy Tester settings (repeat for all 7)

Open Strategy Tester in the RoboForex terminal (portable install) and set:

- [ ] **Expert Advisor**: `EA_DCA_CENT_V1` (from `EA-DCA-V1.0\`)
- [ ] **Symbol**: the symbol under test (EURUSD, GBPUSD, USDJPY, AUDUSD, USDCHF,
      USDCAD, or CADCHF)
- [ ] **Period**: H4
- [ ] **Date range**: `2025.03.01` to `2026.03.01` (the study's original 1-year
      screening window — use the *same* window so the comparison in §3 is
      apples-to-apples)
- [ ] **Model**: **"Every tick based on real ticks"** — not "Every tick" or
      "1 minute OHLC". This EA's touch-mode exits need real-tick modeling
      (`CLAUDE.md`'s own confirmed finding).
- [ ] **Deposit**: 15000, **Currency**: USD, **Leverage**: 1:1000 (the
      account's real native leverage)
- [ ] **Inputs tab**: click **Load**, browse to
      `roboforex_study/sets/cent_portfolio/<SYMBOL>.set`, load it
- [ ] **Before clicking Start**, open the Inputs tab once more and visually
      confirm `InpBBAppliedPrice` reads **PRICE_HIGH** in the dropdown (not
      PRICE_LOW) — this is the one thing that went wrong last time, so it's
      worth eyeballing directly, not just trusting the file loaded correctly.
- [ ] Run the backtest.
- [ ] **After it finishes, check the report's own Settings section** (top of
      the report tab) shows the symbol, date range, and `InpBBAppliedPrice=2`
      you intended — don't just trust the run "looked" successful.

## 2. Record these 5 numbers per symbol — DONE 2026-09-23

Run by Claude Code directly (headless, RoboForex-Pro, Login `52010662`,
verified via each report's own Settings section: correct window
`2025.03.01-2026.03.01`, correct account, and `InpBBAppliedPrice=2`
confirmed present — not just assumed from the `.set` file on disk). Raw
reports: `roboforex_study/reports/viability_recheck/`.

| Symbol | Net Profit | Profit Factor | Recovery Factor | Equity DD Maximal | Total Trades |
|---|---:|---:|---:|---:|---:|
| EURUSD | $220.01 | 2.66 | 0.87 | 1.66% | 76 |
| GBPUSD | $251.84 | 2.87 | 2.27 | 0.74% | 73 |
| USDJPY | $253.13 | 5.99 | 2.81 | 0.60% | 62 |
| AUDUSD | $154.84 | 4.11 | 1.53 | 0.67% | 64 |
| USDCHF | $305.93 | 3.28 | 1.56 | 1.30% | 75 |
| USDCAD | $240.99 | 2.42 | 0.47 | 3.38% | 79 |
| CADCHF | $160.81 | 4.68 | 1.88 | 0.56% | 71 |

## 3. Compare against the pre-fix numbers (same window, wrong price basis)

These are what `SYMBOL_SCREENING_REPORT.md` §A already recorded for this exact
window under `InpBBAppliedPrice=3` (PRICE_LOW) — your new numbers from §2 go in
the same table for direct comparison:

| Symbol | Pre-fix Profit | Pre-fix PF | Pre-fix Recovery | Pre-fix Equity DD | Pre-fix Trades |
|---|---:|---:|---:|---:|---:|
| EURUSD | $177.27 | 4.08 | 2.46 | 0.48% | 56 |
| GBPUSD | $214.42 | 2.71 | 1.93 | 0.74% | 59 |
| USDJPY | $277.29 | 2.30 | 0.39 | 4.69% | 69 |
| AUDUSD | $230.74 | 4.50 | 2.34 | 0.65% | 80 |
| USDCHF | $362.14 | 2.52 | 1.64 | 1.44% | 79 |
| USDCAD | $201.06 | 3.03 | 1.00 | 1.33% | 69 |
| CADCHF | $147.48 | 5.10 | 2.31 | 0.42% | 60 |

## 4. Viability read per symbol — RESULT: materially different, not a clean pass

Delta table (post-fix minus pre-fix):

| Symbol | ΔProfit | ΔPF | ΔRecovery | ΔEquity DD | ΔTrades |
|---|---:|---:|---:|---:|---:|
| EURUSD | +$42.74 | -1.42 | -1.59 | +1.18% | +20 |
| GBPUSD | +$37.42 | +0.16 | +0.34 | +0.00% | +14 |
| **USDJPY** | -$24.16 | **+3.69** | **+2.42** | **-4.09%** | -7 |
| AUDUSD | -$75.90 | -0.39 | -0.81 | +0.02% | -16 |
| USDCHF | -$56.21 | +0.76 | -0.08 | -0.14% | -4 |
| **USDCAD** | +$39.93 | -0.61 | **-0.53** | **+2.05%** | +10 |
| CADCHF | +$13.33 | -0.42 | -0.43 | +0.14% | +11 |

Going through the checklist's own questions:

- [x] **Still net profitable?** Yes, all 7 — no flips to net loss.
- [x] **Profit Factor still meaningfully above 1?** Yes, all 7 stay well
      above 1 (lowest is USDCAD at 2.42).
- [x] **Recovery Factor still positive?** Yes, but **EURUSD's dropped from
      2.46 to 0.87** (a real degradation, still positive) and **USDCAD's
      dropped from 1.00 to 0.47** (also real, and USDCAD was already the
      weakest here).
- [ ] **Equity DD in the same ballpark?** **No — two symbols moved a lot, in
      opposite directions.** USDJPY's dropped from 4.69% to **0.60%** (an
      8x improvement). USDCAD's rose from 1.33% to **3.38%** (2.5x worse).
- [x] **Trade count in a similar range?** Mostly yes (±20 max), confirming
      the fix changed signal *timing* meaningfully but not catastrophically.
- [ ] **Directionally consistent with the pre-fix ranking?** **No.** Two
      genuine reshuffles:

**Finding 1 — USDJPY's "known elevated risk" was largely an artifact of the
bug.** This project has repeatedly cited USDJPY's 4.2-4.7% equity DD as an
accepted risk/reward tradeoff (`CURRENT_PORTFOLIO.md`, multiple BB/QQE
optimization grids, `PROJECT_HANDOFF.md`) — confirmed independently several
times, but always under the wrong price basis. Corrected, USDJPY's DD drops
to **0.60%**, making it one of the *safest* symbols in the portfolio, not the
riskiest, while its Profit Factor (5.99) and Recovery Factor (2.81) are now
the best or near-best of all 7. The "USDJPY carries more risk, kept in for
the profit" framing needs to be retired, not just footnoted.

**Finding 2 — USDCAD's risk-outlier status is reinforced, not resolved.**
Already flagged by five independent methods pre-fix (screening grid, OOS,
trade-level investigation, walk-forward, Monte Carlo). Post-fix, its Recovery
Factor is now the *worst* of the 7 (0.47) and its Equity DD is the *highest*
of the 7 (3.38%, more than double USDCHF's 1.30%, its nearest rival). The
prior "kept in, not disqualified" decision was made without this data point
— worth revisiting specifically for USDCAD in light of it.

**Secondary observation**: AUDUSD's Recovery Factor dropped from 2.34 to
1.53 and profit dropped 33% ($230.74 → $154.84) — still solid, no longer
clearly "the standout." It's not the strongest candidate by these numbers
alone anymore; GBPUSD and USDJPY both look more attractive post-fix on a
risk-adjusted basis.

## 5. What to do with the result

Per the checklist's own decision framework — this is the "materially
different" branch, not "looks broadly similar":

- **USDJPY**: re-frame, don't just re-test. Its risk profile changed enough
  that this project's own repeated characterization of it needs correcting
  in every document that cites it, independent of whether a fuller
  OOS/walk-forward/Monte Carlo re-run happens.
- **USDCAD**: the case for keeping it in without the circuit breaker is
  weaker now than when that decision was made (§D2/§E item 1 in
  `SYMBOL_SCREENING_REPORT.md`) — worth deciding again with this data point
  in hand, not treating the earlier decision as still settled.
- **AUDUSD**: no longer clearly the single best candidate — still fine, just
  not obviously the standout the original (buggy) study made it look like.
- **Full OOS/walk-forward/Monte Carlo re-run**: given two symbols moved this
  much, a full re-validation is more justified now than a spot-check would
  have supported — but that's a scope/budget decision for the user, not
  decided here.
