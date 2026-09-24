# USDCAD Max Floating Loss Circuit Breaker — 8% Threshold Test

**Date**: 2026-09-24. **Window**: USDCAD OOS-B, 2026.03.01-2026.09.19 (same
window as `usdcad_oosb_refix/`, corrected `InpBBAppliedPrice=2`).
**Config**: `roboforex_study/sets/cent_portfolio/USDCAD_breaker8pct.set` —
identical to the deployed `USDCAD.set` except `InpUseMaxFloatingLoss=true`,
`InpMaxFloatingLossPercent=8.0`. Verified via
`scripts/verify_set_against_defaults.py` (only the 2 breaker fields + the
2 already-known deliberate diffs). Report Settings section confirmed
correct symbol/window/InpBBAppliedPrice/breaker fields before trusting
results. Raw report: `usdcad_oosb_breaker8pct_utf8.htm`.

## Result: materially worse than no breaker at all

| Metric | No breaker (`usdcad_oosb_refix`) | 8% breaker |
|---|---:|---:|
| Net Profit | -$34.20 | **-$1,181.28** |
| Profit Factor | 0.95 | **0.04** |
| Recovery Factor | -0.02 | **-0.95** |
| Equity DD Maximal | 10.35% ($1,554.31) | 8.28% ($1,243.38) |
| Trades | 50 | 39 |

## Mechanism, confirmed from the deal log

The breaker fired exactly once, on **2026-06-23 17:22:20**, force-closing
**15 legs across all stacked sequences simultaneously** at price 1.41981 —
realizing a combined loss of **~$1,201** in a single event (Balance
Drawdown Maximal lands at exactly 8.00%, as expected by construction: the
breaker fires the instant floating loss crosses `Balance × 8%`).

Per the original §D2 investigation, USDCAD's adverse move peaked around
**2026-06-25** at ~1.423 before reverting — the breaker fired **2 days
before the actual peak**, forcing liquidation almost at the worst possible
point, just before the reversion that (with no breaker) let the position
recover most of its floating loss and exit for a much smaller ~$453
realized loss on 2026-07-17 via the normal BB Centre Band exit.

The EA reopened new sequences afterward (deals 48-100), which traded
roughly breakeven through July-September, but never recovered the ~$1,200
crystallized by the forced early close — hence the much worse net result.

## Conclusion

**An 8% threshold is too tight for USDCAD** — it reproduces exactly the
failure mode this EA's own code comments already warn about for Equity
Protection at low thresholds ("behaves like the tight per-sequence
trailing already shown to cut winners short"): forcing a loss-crystallizing
exit during a drawdown that was, in this specific historical case, about to
mean-revert. This is not evidence the circuit breaker concept is bad — it's
evidence *this specific threshold* is badly timed for *this specific
episode*. A higher threshold (closer to the 10.35% natural peak, e.g.
11-12%) would only intervene if the episode continued *past* where it
actually stopped historically — which is exactly the scenario the breaker
exists to protect against (a worse continuation that never happened this
time, but isn't guaranteed not to next time). That tradeoff — protecting
against a repeat that goes further, at the cost of this specific historical
case being worse off — is the real shape of the decision, not resolved by
this one test.
