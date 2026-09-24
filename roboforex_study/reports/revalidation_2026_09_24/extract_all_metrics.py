import re
import os

def extract(path):
    with open(path, encoding='utf-8') as f:
        html = f.read()

    def find(label):
        m = re.search(re.escape(label) + r'.*?<b>([^<]*)</b>', html, re.S)
        return m.group(1).strip() if m else 'N/A'

    return {
        'profit': find('Total Net Profit:'),
        'pf': find('Profit Factor:'),
        'recovery': find('Recovery Factor:'),
        'sharpe': find('Sharpe Ratio:'),
        'balance_dd': find('Balance Drawdown Maximal:'),
        'equity_dd': find('Equity Drawdown Maximal:'),
        'trades': find('Total Trades:'),
    }

BASE = os.path.dirname(os.path.abspath(__file__))
SYMBOLS = ['AUDUSD', 'USDCHF', 'CADCHF']

print("=" * 100)
print("WIDER-WINDOW / OOS (revalidation 2026-09-24, corrected InpBBAppliedPrice=2, Model=1)")
print("=" * 100)
print(f"{'Symbol':<8}{'Window':<8}{'Profit':>10}{'PF':>7}{'Recovery':>9}{'BalanceDD':>16}{'EquityDD':>16}{'Trades':>8}")
for sym in SYMBOLS:
    for win, label in [('full', 'Full'), ('oosA', 'OOS-A'), ('oosB', 'OOS-B')]:
        path = f'{BASE}/wider_window_oos/wide2_{sym}_{win}_utf8.htm'
        d = extract(path)
        print(f"{sym:<8}{label:<8}{d['profit']:>10}{d['pf']:>7}{d['recovery']:>9}{d['balance_dd']:>16}{d['equity_dd']:>16}{d['trades']:>8}")
    print()

print("=" * 100)
print("WALK-FORWARD (revalidation 2026-09-24, corrected InpBBAppliedPrice=2, Model=1)")
print("=" * 100)
window_dates = {
    'W1': '2024 H1', 'W2': '2024 H2', 'W3': '2025 H1',
    'W4': '2025 H2', 'W5': '2026 (partial)',
}
print(f"{'Symbol':<8}{'Window':<16}{'Profit':>10}{'PF':>7}{'Recovery':>9}{'EquityDD':>16}{'Trades':>8}")
for sym in SYMBOLS:
    neg_count = 0
    for w in ['W1', 'W2', 'W3', 'W4', 'W5']:
        path = f'{BASE}/walk_forward/wf2_{sym}_{w}_utf8.htm'
        d = extract(path)
        try:
            if float(d['profit']) < 0:
                neg_count += 1
        except ValueError:
            pass
        print(f"{sym:<8}{window_dates[w]:<16}{d['profit']:>10}{d['pf']:>7}{d['recovery']:>9}{d['equity_dd']:>16}{d['trades']:>8}")
    print(f"  -> {sym}: {neg_count}/5 windows negative")
    print()
