# Combined drawdown of the 6-symbol portfolio, from TRL equity logs

**Result: 0.38% combined equity drawdown for all 6 deployed symbols**, vs 0.61%
for the original 3 alone and 1.65% for the worst single symbol (EURUSD). The
earlier figure (0.32%, `../revalidation_2026_09_24/FINDING.md`) came from one
equity snapshot per H4 bar on `Model=1`. This one uses every tick on `Model=4`,
so it is a little deeper, as expected. The diversification conclusion is
unchanged.

## Method

- **Runs:** `TRL_EA_DCA_CENT_V1_Logged` (the cent EA + TRL logger v1.0.1, same
  trades as the original, see `../../../trl_logger/results/comparison_2026-09-25.txt`).
  RoboForex-Pro, H4, 2025.03.01–2026.03.01, `Model=4`, $15,000, 1:1000, each
  symbol's `cent_portfolio` `.set` (`InpBBAppliedPrice=2`). USDCHF and EURUSD
  come from the 2026-09-25 TRL verification batch; the other four were run
  here (`run_logged.sh`, log in `run_log.txt`).
- **Checked:** each log header (symbol, RoboForex-Pro, $15,000, start date)
  and each report's Settings section (window, `InpBBAppliedPrice=2`).
- **Combining** (`combined_dd_from_logger.py`): each log is bucketed into
  5-minute windows and the symbols are aligned by time. "Low" sums each
  symbol's lowest equity in the window, which assumes all six lows coincide
  (conservative). "Close" sums window-end equity.
- **Validation:** each symbol's own logger drawdown matches MT5's Equity
  Drawdown Maximal within $3.28 (0.02 points).

| Symbol | Logger DD | MT5 Equity DD Maximal |
|---|---:|---:|
| EURUSD | $250.69 (1.65%) | $251.89 (1.66%) |
| GBPUSD | $111.11 (0.74%) | $111.13 (0.74%) |
| USDJPY | $90.30 (0.60%) | $90.03 (0.60%) |
| AUDUSD | $101.65 (0.67%) | $100.92 (0.67%) |
| USDCHF | $192.21 (1.28%) | $195.49 (1.30%) |
| CADCHF | $85.68 (0.56%) | $85.41 (0.56%) |

## Combined results (% of the combined peak; each symbol on its own $15,000)

| Combination | DD (close) | DD (low, conservative) | Net profit | Earlier bar-close figure |
|---|---:|---:|---:|---:|
| Existing only (EUR/GBP/JPY) | 0.59% | 0.61% | $724.98 | 0.48% |
| + AUDUSD | 0.56% | 0.58% | $879.82 | 0.45% |
| + USDCHF | 0.56% | 0.56% | $1,030.91 | 0.49% |
| + CADCHF | 0.44% | 0.46% | $885.79 | 0.35% |
| + USDCHF + CADCHF | 0.45% | 0.45% | $1,191.72 | 0.38% |
| + USDCHF + AUDUSD | 0.46% | 0.47% | $1,185.75 | 0.40% |
| + CADCHF + AUDUSD | 0.44% | 0.46% | $1,040.63 | 0.35% |
| **All 6 deployed** | **0.38%** | **0.38%** | **$1,346.56** | 0.32% |

Every figure is about 0.06–0.13 points deeper than the bar-close version. The
ranking is the same: every addition lowers combined drawdown except USDCHF on
its own, and all 6 together is the lowest.

## Limits

- Each symbol ran as a separate backtest with its own full deposit. The sum
  shows how drawdowns overlap in time, not what one shared account would do
  (shared margin and stop-out level). The six combined need about $90,000 of
  deposit on this basis; the dollar drawdown ($345) is the more portable number.
- One year of data (2025.03.01–2026.03.01). The longer windows were not
  combined here.

## Files

- Reports: `TRL_rep_RF_EA_DCA_CENT_V1_Logged_<SYMBOL>_1y.htm` (this folder).
- Equity logs (not committed, per the TRL rules):
  `%APPDATA%\MetaQuotes\Terminal\Common\Files\TRL\TRL_equity_TRL_EA_DCA_CENT_V1_Logged_<SYMBOL>_H4_20250301.csv`
  (the un-suffixed ones; `_2` files are FTMO runs).
- Output: `combined_dd_output.txt`.
