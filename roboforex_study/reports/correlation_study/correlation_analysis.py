import csv
from datetime import datetime, timedelta
import statistics

SYMBOLS = ['EURUSD', 'GBPUSD', 'USDJPY', 'AUDUSD', 'USDCHF', 'USDCAD', 'CADCHF']
START = datetime(2025, 3, 1)
END = datetime(2026, 3, 1)

def load_curve(sym):
    pts = []
    with open(f'equity_{sym}.csv') as f:
        for row in csv.DictReader(f):
            pts.append((datetime.fromisoformat(row['time']), float(row['balance'])))
    return pts

def daily_series(pts):
    # forward-fill onto a daily grid; balance starts at pts[0][1] (15000)
    day = START
    idx = 0
    last_bal = pts[0][1]
    out = []
    while day <= END:
        while idx < len(pts) and pts[idx][0] <= day:
            last_bal = pts[idx][1]
            idx += 1
        out.append((day, last_bal))
        day += timedelta(days=1)
    return out

def pct_returns(series):
    vals = [v for _, v in series]
    rets = []
    for i in range(1, len(vals)):
        prev = vals[i-1]
        rets.append((vals[i] - prev) / prev if prev != 0 else 0.0)
    return rets

def correlation(a, b):
    n = len(a)
    ma = sum(a) / n
    mb = sum(b) / n
    cov = sum((a[i]-ma)*(b[i]-mb) for i in range(n))
    va = sum((x-ma)**2 for x in a)
    vb = sum((x-mb)**2 for x in b)
    if va == 0 or vb == 0:
        return 0.0
    return cov / (va**0.5 * vb**0.5)

def max_drawdown_pct(series):
    vals = [v for _, v in series]
    peak = vals[0]
    worst = 0.0
    worst_day = series[0][0]
    for (day, v) in series:
        if v > peak:
            peak = v
        dd = (peak - v) / peak * 100
        if dd > worst:
            worst = dd
            worst_day = day
    return worst, worst_day

if __name__ == '__main__':
    daily = {}
    returns = {}
    for sym in SYMBOLS:
        pts = load_curve(sym)
        d = daily_series(pts)
        daily[sym] = d
        returns[sym] = pct_returns(d)

    print("=== Max drawdown (daily balance, %) and when it occurred ===")
    for sym in SYMBOLS:
        dd, day = max_drawdown_pct(daily[sym])
        print(f"  {sym:<8} {dd:6.2f}%  on {day.date()}")

    print()
    print("=== Pairwise daily-return correlation matrix ===")
    header = "        " + "".join(f"{s:>9}" for s in SYMBOLS)
    print(header)
    for s1 in SYMBOLS:
        row = f"{s1:<8}"
        for s2 in SYMBOLS:
            c = correlation(returns[s1], returns[s2])
            row += f"{c:9.2f}"
        print(row)

    print()
    print("=== Combined portfolios: existing (EUR+GBP+JPY) vs existing+candidate ===")
    existing = ['EURUSD', 'GBPUSD', 'USDJPY']
    candidates = ['AUDUSD', 'USDCHF', 'USDCAD', 'CADCHF']

    def combined_series(symlist):
        # sum of (balance - 15000) deltas, +15000*len as combined starting base,
        # i.e. combined equity = 15000*N + sum of each symbol's own profit-to-date
        n = len(symlist)
        days = [d for d, _ in daily[symlist[0]]]
        out = []
        for i, day in enumerate(days):
            total = sum(daily[s][i][1] - 15000 for s in symlist) + 15000 * n
            out.append((day, total))
        return out

    base = combined_series(existing)
    base_dd, base_day = max_drawdown_pct(base)
    base_profit = base[-1][1] - base[0][1]
    print(f"Existing portfolio (EURUSD+GBPUSD+USDJPY), equal-weighted $15k each:")
    print(f"  Combined profit: ${base_profit:.2f}   Combined max DD: {base_dd:.2f}% on {base_day.date()}")

    for c in candidates:
        combo = combined_series(existing + [c])
        dd, day = max_drawdown_pct(combo)
        profit = combo[-1][1] - combo[0][1]
        avg_corr = sum(correlation(returns[c], returns[e]) for e in existing) / len(existing)
        print(f"  + {c:<8} combined profit: ${profit:>9.2f}   combined max DD: {dd:5.2f}% on {day.date()}   avg corr vs existing 3: {avg_corr:+.2f}")

    print()
    all4 = combined_series(existing + candidates)
    dd4, day4 = max_drawdown_pct(all4)
    profit4 = all4[-1][1] - all4[0][1]
    print(f"All 7 combined (existing 3 + all 4 Tier-1 candidates):")
    print(f"  Combined profit: ${profit4:.2f}   Combined max DD: {dd4:.2f}% on {day4.date()}")
