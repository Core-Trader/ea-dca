# Phase 2 summary: TP/SL mode per symbol x entry-filter variant, from the MT5 reports
# (headline metrics) and the forensic CSVs (win rate, pips per win/loss).
# Pip = 0.01 for JPY pairs, else 0.0001 (matches the EA's g_pipSize rule).
import csv, os, re

HERE = os.path.dirname(os.path.abspath(__file__))
RUNS = os.path.join(HERE, 'runs')
SYMS = ['EURUSD', 'GBPUSD', 'USDJPY', 'AUDUSD', 'USDCHF', 'CADCHF']
VARS = ['base', 'matrend', 'marev', 'htfd1', 'bbwidth']

def rep(sym, v):
    p = os.path.join(RUNS, f'tpsl_p2_{sym}_{v}_utf8.htm')
    if not os.path.exists(p): return None
    h = open(p, encoding='utf-8').read()
    g = lambda l: (re.search(re.escape(l) + r'.*?<b>([^<]*)</b>', h, re.S) or [0, 'N/A'])[1].strip()
    num = lambda s: float(s.replace(' ', '').split('(')[0]) if s not in ('N/A', '') else float('nan')
    ok = 'InpBBAppliedPrice=2' in h and f'{sym}' in h and '2024.01.01 - 2026.09.19' in h
    return dict(net=num(g('Total Net Profit:')), pf=num(g('Profit Factor:')), trades=int(num(g('Total Trades:'))),
                dd=g('Equity Drawdown Maximal:'), ok=ok)

def trades(sym, v):
    p = os.path.join(RUNS, f'tpsl_p2_{sym}_{v}.csv')
    if not os.path.exists(p): return None
    pip = 0.01 if 'JPY' in sym else 0.0001
    out = []
    for r in csv.DictReader(open(p, encoding='utf-8')):
        d = 1 if r['direction'] == 'buy' else -1
        out.append(d * (float(r['exit']) - float(r['entry'])) / pip)
    return out

def fmt(x, w=7, p=1): return f'{x:>{w}.{p}f}'

rows = {}
print(f"{'Symbol':<7} {'Variant':<8} {'Net $':>8} {'PF':>5} {'Trades':>6} {'Win%':>5} {'AvgWin':>7} {'AvgLoss':>8} {'Equity DD':>16}")
for sym in SYMS:
    for v in VARS:
        r = rep(sym, v); t = trades(sym, v)
        if r is None: print(f'{sym:<7} {v:<8} (not run)'); continue
        w = [x for x in (t or []) if x > 0]; l = [x for x in (t or []) if x <= 0]
        wr = 100 * len(w) / len(t) if t else float('nan')
        aw = sum(w) / len(w) if w else float('nan'); al = sum(l) / len(l) if l else float('nan')
        rows[(sym, v)] = r['net']
        flag = '' if r['ok'] else '  (settings?)'
        print(f"{sym:<7} {v:<8} {r['net']:>8.2f} {r['pf']:>5.2f} {r['trades']:>6} {fmt(wr,5)} {fmt(aw)} {fmt(al,8)} {r['dd']:>16}{flag}")
    print()

print('Net $ by variant (sum over symbols, and symbols with net > 0):')
for v in VARS:
    vals = [rows[(s, v)] for s in SYMS if (s, v) in rows]
    print(f"  {v:<8} total {sum(vals):>9.2f}   profitable on {sum(1 for x in vals if x > 0)}/{len(vals)} symbols")
