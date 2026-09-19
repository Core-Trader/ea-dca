import csv
from datetime import datetime

SYMBOLS = ['EURUSD', 'GBPUSD', 'USDJPY', 'AUDUSD', 'USDCHF', 'USDCAD', 'CADCHF']
EXISTING = ['EURUSD', 'GBPUSD', 'USDJPY']
CANDIDATES = ['AUDUSD', 'USDCHF', 'USDCAD', 'CADCHF']

def load(sym):
    pts = []
    with open(f'equity_forensic_{sym}_123456.csv') as f:
        for row in csv.DictReader(f):
            t = datetime.strptime(row['time'], '%Y.%m.%d %H:%M:%S')
            pts.append((t, float(row['balance']), float(row['equity'])))
    return pts

def returns(vals):
    return [(vals[i] - vals[i-1]) / vals[i-1] if vals[i-1] != 0 else 0.0 for i in range(1, len(vals))]

def correlation(a, b):
    n = len(a)
    ma, mb = sum(a)/n, sum(b)/n
    cov = sum((a[i]-ma)*(b[i]-mb) for i in range(n))
    va = sum((x-ma)**2 for x in a)
    vb = sum((x-mb)**2 for x in b)
    if va == 0 or vb == 0:
        return 0.0
    return cov / (va**0.5 * vb**0.5)

def drawdown_series(vals):
    peak = vals[0]
    dds = []
    for v in vals:
        if v > peak:
            peak = v
        dds.append((peak - v) / peak * 100)
    return dds

def max_dd(dds, times):
    worst = max(dds)
    idx = dds.index(worst)
    return worst, times[idx]

def top_drawdown_episodes(dds, times, threshold_pct):
    # find contiguous stretches where dd >= threshold_pct
    episodes = []
    in_ep = False
    start = None
    peak_dd = 0.0
    peak_t = None
    for i, dd in enumerate(dds):
        if dd >= threshold_pct:
            if not in_ep:
                in_ep = True
                start = times[i]
                peak_dd = dd
                peak_t = times[i]
            elif dd > peak_dd:
                peak_dd = dd
                peak_t = times[i]
        else:
            if in_ep:
                episodes.append((start, times[i-1], peak_dd, peak_t))
                in_ep = False
    if in_ep:
        episodes.append((start, times[-1], peak_dd, peak_t))
    return episodes

if __name__ == '__main__':
    data = {}
    for sym in SYMBOLS:
        pts = load(sym)
        times = [p[0] for p in pts]
        equity = [p[2] for p in pts]
        data[sym] = {'times': times, 'equity': equity, 'returns': returns(equity), 'dd': drawdown_series(equity)}

    print("=== Max EQUITY drawdown (per-bar, H4) and when it occurred ===")
    for sym in SYMBOLS:
        dd, t = max_dd(data[sym]['dd'], data[sym]['times'])
        print(f"  {sym:<8} {dd:6.2f}%  peaked on {t}")

    print()
    print("=== Pairwise EQUITY-return correlation (H4 bars) ===")
    header = "        " + "".join(f"{s:>9}" for s in SYMBOLS)
    print(header)
    for s1 in SYMBOLS:
        row = f"{s1:<8}"
        for s2 in SYMBOLS:
            c = correlation(data[s1]['returns'], data[s2]['returns'])
            row += f"{c:9.2f}"
        print(row)

    print()
    print("=== Drawdown episodes >= 0.3% equity DD, per symbol (top 5 by depth) ===")
    for sym in SYMBOLS:
        eps = top_drawdown_episodes(data[sym]['dd'], data[sym]['times'], 0.3)
        eps.sort(key=lambda e: -e[2])
        print(f"  {sym}: {len(eps)} episodes >=0.3% DD")
        for start, end, peak_dd, peak_t in eps[:5]:
            print(f"    {start.date()} to {end.date()}  peak {peak_dd:.2f}% on {peak_t.date()}")

    print()
    print("=== Combined portfolio equity: existing vs existing+candidate ===")
    def combined(symlist):
        n = len(symlist)
        times = data[symlist[0]]['times']
        combo_eq = []
        for i in range(len(times)):
            total = sum(data[s]['equity'][i] - 15000 for s in symlist) + 15000 * n
            combo_eq.append(total)
        return times, combo_eq

    times_e, eq_e = combined(EXISTING)
    dd_e = drawdown_series(eq_e)
    maxdd_e, t_e = max_dd(dd_e, times_e)
    print(f"Existing (EUR+GBP+JPY): combined max equity DD = {maxdd_e:.2f}% on {t_e}")
    avg_individual_existing = sum(max_dd(data[s]['dd'], data[s]['times'])[0] for s in EXISTING) / len(EXISTING)
    print(f"  (avg of individual symbols' own max DD: {avg_individual_existing:.2f}% -- combining {'REDUCED' if maxdd_e < avg_individual_existing else 'DID NOT reduce'} peak DD vs the average single symbol)")

    for c in CANDIDATES:
        times_c, eq_c = combined(EXISTING + [c])
        dd_c = drawdown_series(eq_c)
        maxdd_c, t_c = max_dd(dd_c, times_c)
        print(f"  + {c:<8} combined max equity DD = {maxdd_c:5.2f}% on {t_c}   (candidate's own solo max DD: {max_dd(data[c]['dd'], data[c]['times'])[0]:.2f}%)")

    times_all, eq_all = combined(EXISTING + CANDIDATES)
    dd_all = drawdown_series(eq_all)
    maxdd_all, t_all = max_dd(dd_all, times_all)
    print(f"\nAll 7 combined: combined max equity DD = {maxdd_all:.2f}% on {t_all}")
