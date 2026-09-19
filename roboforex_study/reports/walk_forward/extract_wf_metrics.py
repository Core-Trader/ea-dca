import re

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
        'equity_dd': find('Equity Drawdown Maximal:'),
        'trades': find('Total Trades:'),
    }

symbols = ['AUDUSD', 'USDCHF', 'USDCAD', 'CADCHF']
windows = ['W1', 'W2', 'W3', 'W4', 'W5']
window_dates = {
    'W1': '2024.01-2024.07', 'W2': '2024.07-2025.01', 'W3': '2025.01-2025.07',
    'W4': '2025.07-2026.01', 'W5': '2026.01-2026.09',
}

print(f"{'Symbol':<8}{'Window':<10}{'Profit':>10}{'PF':>7}{'Recovery':>9}{'EquityDD':>16}{'Trades':>8}")
for sym in symbols:
    neg_count = 0
    for w in windows:
        path = f'wf_{sym}_{w}_utf8.htm'
        d = extract(path)
        try:
            if float(d['profit']) < 0:
                neg_count += 1
        except ValueError:
            pass
        print(f"{sym:<8}{window_dates[w]:<10}{d['profit']:>10}{d['pf']:>7}{d['recovery']:>9}{d['equity_dd']:>16}{d['trades']:>8}")
    print(f"  -> {sym}: {neg_count}/5 windows negative")
    print()
