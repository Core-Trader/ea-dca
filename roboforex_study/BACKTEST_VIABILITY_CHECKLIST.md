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

## 2. Record these 5 numbers per symbol

From the report's **Results** tab:

| Symbol | Net Profit | Profit Factor | Recovery Factor | Equity DD Maximal | Total Trades |
|---|---:|---:|---:|---:|---:|
| EURUSD | | | | | |
| GBPUSD | | | | | |
| USDJPY | | | | | |
| AUDUSD | | | | | |
| USDCHF | | | | | |
| USDCAD | | | | | |
| CADCHF | | | | | |

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

## 4. Viability read per symbol

For each symbol, ask in this order — a "no" earlier in the list matters more
than one later:

- [ ] **Still net profitable?** If a symbol flips to a net loss under the
      corrected price basis, that's a real, not cosmetic, change — flag it,
      don't average it away.
- [ ] **Profit Factor still meaningfully above 1?** (PF 1.0-1.3 is fragile —
      look at trade count too before trusting/distrusting it on a small
      sample.)
- [ ] **Recovery Factor still positive and not collapsed?** A drop from e.g.
      2.3 to 0.3 is a real degradation even if profit stayed positive.
- [ ] **Equity DD in the same ballpark, not suddenly much worse?** Watch
      specifically for anything jumping past ~3-5% for a non-USDJPY symbol —
      USDJPY's own elevated DD is already known/accepted, the other 6
      shouldn't suddenly resemble it.
- [ ] **Trade count still in a similar range?** A big change (e.g. 79 → 30)
      means the signal timing shifted meaningfully under the new price basis
      — expected to some degree (that's the whole point of the fix) but worth
      noting how much.
- [ ] **Directionally consistent with the pre-fix ranking?** You don't need
      exact numbers to match — the interesting question is whether AUDUSD/
      CADCHF are still the strongest, whether USDCAD still looks like the
      relative outlier, or whether the ranking actually reshuffles.

## 5. What to do with the result

- **If the picture looks broadly similar** (same rough ranking, no symbol
  flips to a loss, no dramatic DD blowup): the existing Tier 1
  picks/USDCAD-kept-in decision probably still holds, and the full
  OOS/walk-forward/Monte Carlo re-run can wait until budget allows — update
  the warning banners in `SYMBOL_SCREENING_REPORT.md`/`CURRENT_PORTFOLIO.md`
  to note "spot-checked on the 1-year window, looks consistent" rather than
  leaving them as fully unresolved.
- **If something looks materially different** (a symbol flips negative, DD
  jumps a lot, ranking reshuffles): that's worth a fuller re-validation
  before trusting the portfolio as-is — flag which symbol(s) specifically,
  and we can prioritize just those for the deeper OOS/walk-forward/Monte
  Carlo work rather than redoing all 7 from scratch.
- Either way, **share the filled-in table from §2** and I'll update the
  reports' warning banners to reflect the actual outcome instead of leaving
  them generically "provisional."
