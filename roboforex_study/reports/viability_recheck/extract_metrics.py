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

symbols = ['EURUSD', 'GBPUSD', 'USDJPY', 'AUDUSD', 'USDCHF', 'USDCAD', 'CADCHF']
print(f"{'Symbol':<8}{'Profit':>10}{'PF':>7}{'Recovery':>9}{'EquityDD':>16}{'Trades':>8}")
for sym in symbols:
    d = extract(f'viability_{sym}_utf8.htm')
    print(f"{sym:<8}{d['profit']:>10}{d['pf']:>7}{d['recovery']:>9}{d['equity_dd']:>16}{d['trades']:>8}")
