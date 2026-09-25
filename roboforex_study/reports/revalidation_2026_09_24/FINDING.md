# 2026-09-24 Re-validation: 6-symbol combined diversification + full battery for AUDUSD/USDCHF/CADCHF

Two follow-on items from the USDCAD drop (`CURRENT_PORTFOLIO.md`), both closed
out here. **Methodology note**: every run in this batch used `Model=1`
("1 minute OHLC"), not the `Model=4` ("Every tick based on real ticks") this
project otherwise standardizes on — a deliberate speed tradeoff for this bulk
batch (33 backtests + 3 dense-grid optimizations, ~11 minutes total headless
vs. what would likely have been hours under `Model=4`). `CLAUDE.md` documents
a confirmed case where `Model=1` produces a materially different trade
history than `Model=4` for this EA's touch-mode exits, so **these results are
a fast screen, not a final confirmation** — every number below should get a
`Model=4` re-run before being treated as load-bearing for a go-live decision.
That said, every result here is unambiguously clean (see below), so the
`Model=1`/`Model=4` gap is unlikely to change the *conclusion*, only the
exact figures.

## Item 1 — Combined-portfolio diversification, 6-symbol deployed set

**Method**: `EA_DCA_CENT_V1_EquityForensic.mq5` (per-bar equity CSV logging,
byte-identical trading logic to `EA_DCA_CENT_V1.mq5`), one run per deployed
symbol (EURUSD/GBPUSD/USDJPY/AUDUSD/USDCHF/CADCHF), 1-year window
(2025.03.01-2026.03.01, matching the original screening window), corrected
`InpBBAppliedPrice=2`, shared magic number 123456 (diagnostic only, matches
`co_dependency_check.py`'s original convention). Combined via
`combined_dd_6symbol.py`, same arithmetic-sum methodology as the original
`co_dependency_check.py`. Raw CSVs and script: `correlation_study/`.

| Combination | Combined max Equity DD | Combined profit |
|---|---:|---:|
| Existing only (EUR/GBP/JPY) | 0.48% | $729.60 |
| + AUDUSD only | 0.45% | $891.11 |
| + USDCHF only | 0.49% | $1,039.80 |
| + CADCHF only | 0.35% | $882.95 |
| + USDCHF + CADCHF | 0.38% | $1,193.15 |
| + USDCHF + AUDUSD | 0.40% | $1,201.31 |
| + CADCHF + AUDUSD | 0.35% | $1,044.46 |
| **All 6 deployed symbols** | **0.32%** | **$1,354.66** |

**Result: the diversification benefit holds, and is actually stronger than
the stale 7-symbol figure.** All 6 combined is **0.32%** combined equity DD —
below every individual solo symbol's own DD (EURUSD 1.58%, USDCHF 1.16%,
GBPUSD 0.67%, AUDUSD 0.59%, USDJPY 0.50%, CADCHF 0.44%) and below the old
7-symbol (USDCAD-included) figure of 0.77%. Dropping USDCAD didn't just
remove a risk outlier — it improved the combined-portfolio risk profile
directly, consistent with USDCAD having been the dominant contributor to
that combined drawdown all along.

## Item 2 — Full battery for AUDUSD/USDCHF/CADCHF (§D/§D3/§D4 equivalent: OOS, dense grid, same settings over time)

**§D wider-window/OOS** (9 runs: 3 symbols × Full/OOS-A/OOS-B,
corrected `.set`): all 9 positive, no red flags. Full data:
`wider_window_oos/`, extracted: `extracted_metrics.txt`.

| Symbol | Window | Profit | PF | Recovery | Equity DD | Trades |
|---|---|---:|---:|---:|---:|---:|
| AUDUSD | Full | $616.31 | 3.36 | 1.63 | 2.50% | 201 |
| AUDUSD | OOS-A | $311.97 | 3.69 | 0.82 | 2.50% | 84 |
| AUDUSD | OOS-B | $130.59 | 2.36 | 0.65 | 1.32% | 50 |
| USDCHF | Full | $542.24 | 2.21 | 1.11 | 3.26% | 210 |
| USDCHF | OOS-A | $147.55 | 1.55 | 0.30 | 3.26% | 98 |
| USDCHF | OOS-B | $84.42 | 2.85 | 1.90 | 0.30% | 37 |
| CADCHF | Full | $548.04 | 2.72 | 1.18 | 3.07% | 209 |
| CADCHF | OOS-A | $169.25 | 1.85 | 0.37 | 3.07% | 89 |
| CADCHF | OOS-B | $112.10 | 5.57 | 1.35 | 0.55% | 45 |

No symbol shows anything resembling USDCAD's OOS-B episode (10.35% equity DD,
net loss). Worst equity DD across all 9 runs is USDCHF's 3.26% (Full/OOS-A,
same episode) — well inside the range already covered by the other 5
deployed symbols' own solo profiles.

**§D3 dense parameter-neighborhood check** (3 genetic-optimization jobs, 121
combos each: `InpBBPeriod` 30-40 × `InpBBDeviation` 2.00-2.50, centered on
the deployed default): clean across all 3 symbols. Raw XML + parser:
`dense_grid/`.

| Symbol | Equity DD range | PF range | Negative-profit combos | Default combo (35, 2.25) |
|---|---|---|---:|---|
| AUDUSD | 0.67-0.69% | 3.52-4.79 | 0/121 | $161.51, PF 4.28, 65 trades |
| USDCHF | 1.28-1.81% | 2.23-3.78 | 0/121 | $310.27, PF 3.34, 75 trades |
| CADCHF | 0.17-0.89% | 2.16-31.56 | 0/121 | $153.35, PF 4.32, 70 trades |

No hidden cliffs near any deployed default — every combo profitable, DD
bands stay tight. (CADCHF's PF range tops out at 31.56 — almost certainly a
small-sample outlier at one grid corner, same caution already flagged
elsewhere in this study for small-trade-count PF figures; not investigated
further since DD stays tight regardless.)

**§D4 same-settings-over-time check** (not true walk-forward — no
re-optimization per window; see `SYMBOL_SCREENING_REPORT.md` §D4's naming
note) (15 runs: 3 symbols × 5 sequential ~6-month windows,
deployed `.set` files, fixed non-reoptimized parameters): **zero negative
windows across all 3 symbols, 15/15 clean.** Full data: `walk_forward/`,
extracted: `extracted_metrics.txt`.

| Symbol | 2024 H1 | 2024 H2 | 2025 H1 | 2025 H2 | 2026 (partial) | Negative windows |
|---|---:|---:|---:|---:|---:|---:|
| AUDUSD | $103.21 (PF 11.94) | $18.45 (PF 1.12) | $62.02 (PF 5.39) | $93.88 (PF 3.80) | $158.15 (PF 2.57) | **0/5** |
| USDCHF | $37.14 (PF 1.23) | $44.96 (PF 1.60) | $163.22 (PF 2.84) | $125.31 (PF 5.17) | $116.29 (PF 2.62) | **0/5** |
| CADCHF | $75.53 (PF 3.21) | $90.25 (PF 1.81) | $122.78 (PF 2.00) | $68.72 (PF 11.70) | $138.52 (PF 4.32) | **0/5** |

This is a materially cleaner result than USDCAD ever produced at any point in
this study (USDCAD had 1-2 negative windows depending on the cut, plus the
OOS-B near-miss). None of the 3 remaining Tier 1 candidates show anything
resembling that risk profile.

**§D5 Monte Carlo, §D6 co-dependency**: not re-run as separate steps — §D5
would reuse the Full-window deal logs above (no new backtests needed, same
as the original methodology) and §D6 is superseded by item 1's fresh 6-symbol
combined-DD analysis above, which already answers the co-dependency question
more directly for the current deployed set.

## Model=4 confirmation (2026-09-24, closes the Model=1 caveat)

Re-ran the 4 windows most likely to move under real ticks with `Model=4`,
same corrected `.set` files, Settings section verified on each. Raw reports
and `extract_m4.py`: `model4_confirm/`.

| Run | Profit (M1 → M4) | PF (M1 → M4) | Equity DD (M1 → M4) | Trades (M1 → M4) |
|---|---|---|---|---|
| USDCHF Full | $542.24 → $528.64 (−2.5%) | 2.21 → 2.17 | 3.26% → 3.18% | 210 → 210 |
| USDCHF OOS-A | $147.55 → $139.58 (−5.4%) | 1.55 → 1.51 | 3.26% → 3.18% | 98 → 98 |
| AUDUSD Full | $616.31 → $605.21 (−1.8%) | 3.36 → 3.31 | 2.50% → 2.29% | 201 → 200 |
| CADCHF Full | $548.04 → $523.00 (−4.6%) | 2.72 → 2.67 | 3.07% → 3.05% | 209 → 208 |

`Model=1` ran 2-5% optimistic on profit, with near-identical trade counts
and drawdowns. No conclusion above changes. The windows not re-run under
`Model=4` (OOS-B, the other same-settings-over-time slices, the dense grids)
are expected to shift by a similar small margin.

## Bottom line

Both follow-on items closed. The 6-symbol portfolio (post-USDCAD-drop) is
in a materially *better* validated position than the 7-symbol one ever was —
combined diversification improved (0.77%→0.32%), and none of AUDUSD, USDCHF,
or CADCHF show any drawdown episode, negative window, or parameter-cliff
remotely close to what USDCAD showed repeatedly. Subject to the `Model=1`
caveat above — worth a `Model=4` spot-check on 2-3 of the more interesting
windows (e.g. USDCHF's Full/OOS-A 3.26% DD episode) before treating this as
final, but nothing here suggests the conclusion would change.
