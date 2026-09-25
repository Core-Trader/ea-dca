# Per-trade diagnosis of TP/SL mode from DCA_EA_TPSL_Forensic CSVs (EURUSD, pip = 0.0001).
# Exit "SL" = broker stop-loss comment ("sl ..."); "EA" = closed by the EA's exit logic.
# The TP what-if caps each trade at +X pips if its MFE reached X before it closed.
# MFE is recorded before the close, so a TP at X would have filled first. It is a
# first-order estimate: it ignores that earlier exits would change later trades.
import csv, sys, statistics as st

PIP = 0.0001

def load(path):
    rows = []
    for r in csv.DictReader(open(path, encoding='utf-8')):
        d = 1 if r['direction'] == 'buy' else -1
        pips = d * (float(r['exit']) - float(r['entry'])) / PIP
        rows.append(dict(pips=pips, usd=float(r['realized_profit']), mfe=float(r['mfe_pips']),
                         mae=float(r['mae_pips']), hours=float(r['duration_hours']),
                         exit='SL' if r['exit_comment'].lower().startswith('sl') else 'EA'))
    return rows

def s(v): return f"{st.mean(v):7.1f}" if v else "    n/a"

for tag in sys.argv[1:]:
    t = load(f'{tag}_tpsl_forensic_1_0_0.csv')
    win = [x for x in t if x['pips'] > 0]; loss = [x for x in t if x['pips'] <= 0]
    sl = [x for x in t if x['exit'] == 'SL']; ea = [x for x in t if x['exit'] == 'EA']
    print(f"=== {tag}: {len(t)} trades, net {sum(x['pips'] for x in t):.1f} pips / ${sum(x['usd'] for x in t):.2f}")
    print(f"win rate {100*len(win)/len(t):.1f}%  avg win {s([x['pips'] for x in win])} pips  avg loss {s([x['pips'] for x in loss])} pips")
    for name, g in [('SL exits', sl), ('EA exits', ea)]:
        print(f"  {name:<9} n={len(g):>3}  avg result {s([x['pips'] for x in g])}  avg MFE {s([x['mfe'] for x in g])}  avg MAE {s([x['mae'] for x in g])}  avg hours {s([x['hours'] for x in g])}")
    ea_win = [x for x in ea if x['pips'] > 0]
    if ea_win:
        gb = 1 - sum(x['pips'] for x in ea_win) / sum(x['mfe'] for x in ea_win)
        print(f"  EA-exit winners: giveback {100*gb:.1f}% of MFE")
    print("  Losing trades that were in profit first:")
    for lvl in (10, 20, 30, 50):
        n = sum(1 for x in loss if x['mfe'] >= lvl)
        print(f"    MFE >= {lvl:>2} pips before losing: {n}/{len(loss)}")
    print("  Winners' worst adverse move (MAE) vs the 50-pip SL:")
    for lvl in (20, 30, 40):
        n = sum(1 for x in win if -x['mae'] >= lvl)
        print(f"    MAE >= {lvl} pips: {n}/{len(win)}")
    print("  What-if fixed TP (pips) on the same trades:")
    base = sum(x['pips'] for x in t)
    for tp in (20, 30, 40, 50, 60, 80):
        tot = sum(tp if x['mfe'] >= tp else x['pips'] for x in t)
        hit = sum(1 for x in t if x['mfe'] >= tp)
        print(f"    TP {tp:>2}: net {tot:7.1f} pips (actual {base:.1f}), TP hit on {hit}/{len(t)}")
    # Tighter SL: any trade whose MAE reached -S would have been stopped at -S.
    print("  What-if tighter SL (pips) on the same trades:")
    for sl_p in (30, 40):
        tot = sum(-sl_p if -x['mae'] >= sl_p else x['pips'] for x in t)
        cut = sum(1 for x in win if -x['mae'] >= sl_p)
        print(f"    SL {sl_p}: net {tot:7.1f} pips (actual {base:.1f}), winners cut: {cut}/{len(win)}")
    # Both, pessimistic: if a trade reached both levels, assume the SL came first.
    print("  What-if TP + tighter SL (pessimistic: SL assumed first if both reached):")
    for tp, sl_p in ((30, 30), (30, 40), (40, 40)):
        tot = 0.0
        for x in t:
            if -x['mae'] >= sl_p: tot -= sl_p
            elif x['mfe'] >= tp: tot += tp
            else: tot += x['pips']
        print(f"    TP {tp} / SL {sl_p}: net {tot:7.1f} pips")
    print()
