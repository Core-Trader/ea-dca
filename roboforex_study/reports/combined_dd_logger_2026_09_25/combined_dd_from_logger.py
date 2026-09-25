# Combined-portfolio equity drawdown from TRL equity logs (logger v1.0.1).
# Replaces the row-index alignment of correlation_study/combined_dd_6symbol.py:
# logger rows are irregular, so each log is bucketed into 5-minute windows and
# the symbols are aligned by window start. A window with no row for a symbol
# carries that symbol's last equity forward (no row = no ticks, or nothing at
# risk and nothing moving).
#
# Two combined series are measured:
#   close  - sum of each symbol's equity at the end of each window
#   low    - sum of each symbol's lowest equity in each window. Conservative:
#            it assumes every symbol's low in a window happened at the same time.
# Drawdown at a window = (highest combined close before it - value) / that peak.
# Peaks come from window closes, so they can sit slightly below a true
# intra-window high.
import csv, os, re, sys
from datetime import datetime

HERE = os.path.dirname(os.path.abspath(__file__))
COMMON = os.path.join(os.environ['APPDATA'], 'MetaQuotes', 'Terminal', 'Common', 'Files', 'TRL')
LOG = 'TRL_equity_TRL_EA_DCA_CENT_V1_Logged_{}_H4_20250301.csv'
REPORT = 'TRL_rep_RF_EA_DCA_CENT_V1_Logged_{}_1y.htm'
SYMBOLS = ['EURUSD', 'GBPUSD', 'USDJPY', 'AUDUSD', 'USDCHF', 'CADCHF']
EXISTING = ['EURUSD', 'GBPUSD', 'USDJPY']
DEPOSIT = 15000.0
BUCKET = 300

def load(sym):
    path = os.path.join(COMMON, LOG.format(sym))
    with open(path, encoding='utf-8', errors='replace') as f:
        lines = [l for l in f if not l.startswith('#')]
    b = {}
    for row in csv.DictReader(lines):
        t = int(datetime.strptime(row['time'], '%Y.%m.%d %H:%M:%S').timestamp())
        k = t - t % BUCKET
        lo, cl = float(row['equity_min']), float(row['equity_close'])
        if k in b:
            b[k] = (min(b[k][0], lo), cl)          # rows are in time order: last close wins
        else:
            b[k] = (lo, cl)
    return b

def report_dd(sym):
    raw = open(os.path.join(HERE, REPORT.format(sym)), 'rb').read().decode('utf-16')
    m = re.search(r'Equity Drawdown Maximal:.*?<b>([^<]*)</b>', raw, re.S)
    return m.group(1).strip() if m else 'N/A'

def max_dd(close, low):
    peak, worst_pct, worst_abs = close[0], 0.0, 0.0
    for c, l in zip(close, low):
        dd = peak - min(c, l)
        if peak > 0 and dd / peak > worst_pct:
            worst_pct, worst_abs = dd / peak, dd
        peak = max(peak, c)
    return worst_pct * 100, worst_abs

data = {s: load(s) for s in SYMBOLS}
keys = sorted(set().union(*[d.keys() for d in data.values()]))

series = {}
for s in SYMBOLS:
    lows, closes, last = [], [], DEPOSIT
    for k in keys:
        if k in data[s]:
            lo, cl = data[s][k]
            lows.append(lo); closes.append(cl); last = cl
        else:
            lows.append(last); closes.append(last)
    series[s] = (closes, lows)

def combined(syms):
    close = [sum(series[s][0][i] for s in syms) for i in range(len(keys))]
    low = [sum(series[s][1][i] for s in syms) for i in range(len(keys))]
    return close, low

print(f'5-minute windows: {len(keys)}  ({datetime.fromtimestamp(keys[0]):%Y-%m-%d} to {datetime.fromtimestamp(keys[-1]):%Y-%m-%d})\n')

print('Per-symbol check against each MT5 report')
print(f"{'Symbol':<8}{'Logger DD (low)':>22}{'MT5 Equity DD Maximal':>26}")
for s in SYMBOLS:
    pct, ab = max_dd(*series[s])
    print(f"{s:<8}{ab:>12.2f} ({pct:5.2f}%){report_dd(s):>26}")

combos = {
    'Existing only (EUR/GBP/JPY)': EXISTING,
    'Existing + AUDUSD': EXISTING + ['AUDUSD'],
    'Existing + USDCHF': EXISTING + ['USDCHF'],
    'Existing + CADCHF': EXISTING + ['CADCHF'],
    'Existing + USDCHF + CADCHF': EXISTING + ['USDCHF', 'CADCHF'],
    'Existing + USDCHF + AUDUSD': EXISTING + ['USDCHF', 'AUDUSD'],
    'Existing + CADCHF + AUDUSD': EXISTING + ['CADCHF', 'AUDUSD'],
    'All 6 deployed symbols': SYMBOLS,
}
print('\nCombined portfolio (each symbol on its own $15,000; % of combined peak)')
print(f"{'Combination':<30}{'DD close':>11}{'DD low (conservative)':>24}{'Net profit':>13}")
for name, syms in combos.items():
    close, low = combined(syms)
    p_close, _ = max_dd(close, close)
    p_low, a_low = max_dd(close, low)
    print(f"{name:<30}{p_close:>10.2f}%{p_low:>14.2f}% ({a_low:7.2f}){close[-1] - close[0]:>13.2f}")
