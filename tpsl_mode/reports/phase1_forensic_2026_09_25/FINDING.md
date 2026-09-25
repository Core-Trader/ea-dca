# TP/SL mode — phase 1 diagnosis (2026-09-25)

**Result: TP/SL mode loses because its entries have too little edge as
standalone trades. Its exits aren't the main problem.** With a 50-pip stop,
winners average 24 pips and losers about 48, so it needs to win about 67% of
the time to break even; it wins 56%. No fixed take-profit or tighter stop
tested here turns it profitable, even before accounting for knock-on effects
on later trades.

Also found: **all 8 TP/SL test sets in `tpsl_mode/tpsl_test_sets/` use the
stale `InpBBAppliedPrice=3` / `InpMAAppliedPrice=1`** (the EA's defaults are
2 and 0, fixed in the RoboForex sets on 2026-09-20, never in these). Every
earlier TP/SL result was measured on the wrong Bollinger Band price. Correcting
it makes Test B worse, not better.

## Runs

`DCA_EA_TPSL_Forensic.mq5` (trading logic identical to `DCA_EA.mq5`; only
comments and logging differ, checked by diff), FTMO terminal, account
`540291482`, EURUSD H4, 2025.01.01–2026.01.22, `Model=4`, $100,000, 1:30,
`test_B_fixed_pips.set` (Fixed Pips SL 50, BB Centre Band exit). Settings
checked in each report. Script: `run_forensic.sh`; log: `run_log.txt`.

| Run | Price inputs | Net profit | PF | Trades | Equity DD |
|---|---|---:|---:|---:|---:|
| Stale (as stored) | BB 3 / MA 1 | −$32.93 | 0.67 | 41 | 0.06% |
| Corrected | BB 2 / MA 0 | −$44.78 | 0.60 | 53 | 0.07% |

The stale run reproduces the known Test B result exactly
(`TPSL_EQUITY_BALANCE_ROOT_CAUSE.md` §8a), which confirms the forensic build.
The CSVs hold one trade fewer than each report: the position still open at
the end of the test is closed by the Tester and isn't logged.

## Per-trade diagnosis (corrected run, 52 logged trades)

Full output: `trade_analysis.txt` (script `analyze_trades.py`).

| | Count | Avg result | Avg best move (MFE) | Avg worst move (MAE) |
|---|---:|---:|---:|---:|
| Stopped out (SL) | 22 | −50.2 pips | +19.1 | −49.7 |
| Closed by the EA (BB exit) | 30 | +23.1 pips | +30.8 | −15.4 |

- **Win rate 55.8%, average win 23.9 pips, average loss 48.0 pips.** The
  payoff ratio (0.5) needs a win rate of about 67% to break even.
- **Most losers never got going:** 10 of 23 losing trades never reached
  +10 pips, and only 6 reached +30 before turning into a loss.
- **Winners don't need a 50-pip stop:** only 2 of 29 winners moved 40+ pips
  against the position before winning.
- **The BB exit still gives back 25% of each winner's best move**, the same
  as the earlier study found.

## What-ifs (same trades, first-order estimates)

These cap or stop each trade using its recorded best and worst moves. They
ignore that an earlier exit changes which later trades happen, so treat them
as direction, not forecasts. Actual net: −412.5 pips.

| Change | Net pips |
|---|---:|
| Take-profit 20 | −143.1 |
| **Take-profit 30** | **−114.8** |
| Take-profit 40 | −251.5 |
| Take-profit 60 | −313.2 |
| Stop 40 (instead of 50) | −297.5 |
| Stop 30 | −309.8 |
| TP 30 / SL 30 (SL assumed first if both reached) | −497.0 |
| TP 40 / SL 40 (same assumption) | −406.7 |

Nothing tested reaches break-even. Exit settings can shrink the loss but
can't create an edge the entries don't have.

## What this points to

1. **Entries are the lever.** The EA already has entry filters that have
   never been tested in TP/SL mode: the MA trend filter (`InpUseMAFilter`),
   higher-timeframe direction (`InpTradeInHigherTFDirection`), the BB width
   filter and the minimum signal distance. Testing these needs no code change.
2. **Size exits to volatility, not fixed pips:** the ATR-based SL type exists
   and could be paired with a take-profit near the observed 20–30-pip sweet
   spot.
3. **Check other symbols before changing any code** (phase 2): this is one
   symbol and one year.
4. **Decide what to do with the stale test sets.** Correcting them changes
   the DCA regression baseline (`test_A`) too, so it needs a new baseline run.

Limits: one symbol, one 13-month window, 52 trades. The what-ifs are
approximations.
