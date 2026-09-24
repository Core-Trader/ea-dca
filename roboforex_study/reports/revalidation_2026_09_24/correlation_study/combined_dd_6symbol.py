import csv

SYMBOLS = ['EURUSD', 'GBPUSD', 'USDJPY', 'AUDUSD', 'USDCHF', 'CADCHF']
EXISTING = ['EURUSD', 'GBPUSD', 'USDJPY']

def load(sym):
    equity = []
    with open(f'equity_forensic_{sym}_123456.csv') as f:
        for row in csv.DictReader(f):
            equity.append(float(row['equity']))
    return equity

def max_drawdown_pct(vals):
    peak = vals[0]
    worst = 0.0
    for v in vals:
        if v > peak:
            peak = v
        dd = (peak - v) / peak * 100
        if dd > worst:
            worst = dd
    return worst

if __name__ == '__main__':
    data = {sym: load(sym) for sym in SYMBOLS}
    n_bars = min(len(data[s]) for s in SYMBOLS)
    print(f"Bar counts: {[(s, len(data[s])) for s in SYMBOLS]} -- using n_bars={n_bars}")

    def combined(symlist):
        n = len(symlist)
        return [sum(data[s][i] - 15000 for s in symlist) + 15000 * n for i in range(n_bars)]

    combos = {
        'Existing only (EUR/GBP/JPY)': EXISTING,
        'Existing + AUDUSD only': EXISTING + ['AUDUSD'],
        'Existing + USDCHF only': EXISTING + ['USDCHF'],
        'Existing + CADCHF only': EXISTING + ['CADCHF'],
        'Existing + USDCHF + CADCHF': EXISTING + ['USDCHF', 'CADCHF'],
        'Existing + USDCHF + AUDUSD': EXISTING + ['USDCHF', 'AUDUSD'],
        'Existing + CADCHF + AUDUSD': EXISTING + ['CADCHF', 'AUDUSD'],
        'All 6 deployed symbols combined': SYMBOLS,
    }

    print(f"\n{'Combination':<40}{'Combined max Equity DD':>25}{'Combined profit':>18}")
    for name, symlist in combos.items():
        series = combined(symlist)
        dd = max_drawdown_pct(series)
        profit = series[-1] - series[0]
        print(f"{name:<40}{dd:>24.2f}%{profit:>17.2f}")

    print(f"\nSolo max Equity DD per symbol (for reference):")
    for sym in SYMBOLS:
        dd = max_drawdown_pct(data[sym])
        print(f"  {sym}: {dd:.2f}%")
