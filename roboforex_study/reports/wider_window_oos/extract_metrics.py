import re
import glob

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

symbols = ['AUDUSD', 'USDCHF', 'USDCAD', 'CADCHF']
windows = ['full', 'oosA', 'oosB']

print(f"{'Symbol':<8}{'Window':<8}{'Profit':>10}{'PF':>7}{'Recovery':>9}{'Sharpe':>8}{'BalDD':>16}{'EqDD':>18}{'Trades':>8}")
for sym in symbols:
    for w in windows:
        path = f'wide_{sym}_{w}_utf8.htm'
        d = extract(path)
        print(f"{sym:<8}{w:<8}{d['profit']:>10}{d['pf']:>7}{d['recovery']:>9}{d['sharpe']:>8}{d['balance_dd']:>16}{d['equity_dd']:>18}{d['trades']:>8}")
