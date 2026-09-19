import csv

SYMBOLS = ['EURUSD', 'GBPUSD', 'USDJPY', 'AUDUSD', 'USDCHF', 'USDCAD', 'CADCHF']
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
    n_bars = len(data[EXISTING[0]])

    def combined(symlist):
        n = len(symlist)
        return [sum(data[s][i] - 15000 for s in symlist) + 15000 * n for i in range(n_bars)]

    combos = {
        'Existing only (baseline)': EXISTING,
        'Existing + AUDUSD only': EXISTING + ['AUDUSD'],
        'Existing + USDCHF only': EXISTING + ['USDCHF'],
        'Existing + CADCHF only': EXISTING + ['CADCHF'],
        'Existing + USDCAD only': EXISTING + ['USDCAD'],
        'Existing + USDCHF + CADCHF (the pair in question)': EXISTING + ['USDCHF', 'CADCHF'],
        'Existing + USDCHF + AUDUSD': EXISTING + ['USDCHF', 'AUDUSD'],
        'Existing + CADCHF + AUDUSD': EXISTING + ['CADCHF', 'AUDUSD'],
        'Existing + USDCHF + USDCAD': EXISTING + ['USDCHF', 'USDCAD'],
        'Existing + CADCHF + USDCAD': EXISTING + ['CADCHF', 'USDCAD'],
        'Existing + AUDUSD + USDCAD': EXISTING + ['AUDUSD', 'USDCAD'],
        'All 4 combined': EXISTING + ['AUDUSD', 'USDCHF', 'USDCAD', 'CADCHF'],
    }

    print(f"{'Combination':<55}{'Combined max Equity DD':>25}{'Combined profit':>18}")
    for name, symlist in combos.items():
        series = combined(symlist)
        dd = max_drawdown_pct(series)
        profit = series[-1] - series[0]
        print(f"{name:<55}{dd:>24.2f}%{profit:>17.2f}")
