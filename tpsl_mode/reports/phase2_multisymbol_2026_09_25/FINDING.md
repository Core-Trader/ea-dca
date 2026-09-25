# TP/SL mode — phase 2: six symbols, entry filters (2026-09-25)

**Result: no entry filter gives TP/SL mode an edge.** Across the six
portfolio symbols over 2.7 years, the plain configuration is roughly
break-even at best (−$163.58 in total, profitable on 3 of 6 symbols by
$0.25–$19.67). The trend filters raise the win rate to 65–85% but shrink the
average win to 10–27 pips, while every stop-out still costs about 50 pips, so
they don't turn it profitable either.

## Runs

`DCA_EA_TPSL_Forensic.mq5` (trading logic identical to `DCA_EA.mq5`),
RoboForex-Pro `52010662`, H4, 2024.01.01–2026.09.19, `Model=4`, $15,000,
1:1000. 6 symbols × 5 variants = 30 runs, all finished with no failures
(`run_log.txt`). Each report's settings were checked by the analysis script
(window, symbol, `InpBBAppliedPrice=2`).

All variants start from the corrected `test_B` (TP/SL mode, Fixed Pips SL 50,
BB Centre Band exit, 0.01 lot, max 3 per direction). `sets/`:

| Variant | Change from base |
|---|---|
| `base` | none |
| `matrend` | MA filter on, trend-following (buy above EMA 50) |
| `marev` | MA filter on, mean-reversion (buy below EMA 50) |
| `htfd1` | trade only in the D1 direction |
| `bbwidth` | BB width filter on at 0.5% |

## Results (`phase2_summary.txt`, script `analyze_phase2.py`)

| Variant | Total net (6 symbols) | Profitable symbols | Win rate | Avg win | Avg loss |
|---|---:|---:|---:|---:|---:|
| base | −$163.58 | 3/6 | 56–74% | 14–44 pips | ~−51 |
| matrend | −$101.78 | 1/6 | 74–84% | 10–13 pips | ~−50 |
| marev | −$173.67 | 2/6 | 53–72% | 15–55 pips | ~−51 |
| **htfd1** | **−$85.74** | 2/6 | 65–85% | 11–27 pips | ~−51 |
| bbwidth | −$163.32 | 3/6 | same as base | same as base | same as base |

Per symbol, the base configuration ranges from −$75.89 (EURUSD, PF 0.71) to
+$19.67 (AUDUSD, PF 1.12). The best single result is AUDUSD with the D1
filter: +$24.85, PF 1.41, 75 trades, equity DD 0.10%. Over 2.7 years that is
too small to tell apart from noise. For comparison, DCA mode made
$540–616 on AUDUSD, USDCHF and CADCHF over the same window
(`roboforex_study/reports/revalidation_2026_09_24/FINDING.md`).

## What this shows

- **The payoff shape is the constant problem.** Every stop-out costs about
  50 pips; the BB Centre Band exit closes winners at 10–45 pips. Filters
  change which trades are taken, not that ratio.
- **Trend filters help the win rate and drawdown, not the result.** Trading
  with the trend makes the quick BB-centre exit come sooner, so wins shrink
  as fast as the win rate rises.
- **The BB width filter at 0.5% never binds** on H4 with BB 35/2.25: results
  are identical to base on 5 of 6 symbols (USDJPY differs by $0.26). A real
  test would need a threshold near the typical band width.
- **Mean-reversion MA filtering is mixed and worse overall:** it helps a
  little on EURUSD, USDJPY and CADCHF, and hurts GBPUSD, AUDUSD and USDCHF.

## Suggested next step (phase 3, needs approval)

The one lever left without code changes is the stop and exit shape, combined
with the D1 filter, which gave the highest win rates. Phase 3 could optimize
the SL distance (or the ATR-based SL) and the exit strategy with the D1
filter on. It would be tuned on 2024.01–2025.06 and checked unseen on
2025.07–2026.09.

A stopping rule is worth agreeing up front. If no setting holds a profit
factor above ~1.2 on the unseen period on at least 4 of 6 symbols, park TP/SL
mode. DCA mode is the working strategy. (The 1.2 and 4-of-6 cut-offs are a
proposal, not a sourced threshold.)

Limits: one parameter set per variant (no tuning yet), fixed 0.01 lot, one
2.7-year window, no out-of-sample split in this phase.
