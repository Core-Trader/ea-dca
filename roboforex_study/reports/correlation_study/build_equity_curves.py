import re
import csv
from datetime import datetime

SYMBOLS = ['EURUSD', 'GBPUSD', 'USDJPY', 'AUDUSD', 'USDCHF', 'USDCAD', 'CADCHF']

def parse_deals(path):
    with open(path, encoding='utf-8') as f:
        html = f.read()

    # Find the Deals table section
    deals_start = html.find('>Deals<')
    table = html[deals_start:]

    # Match each row's cells
    row_re = re.compile(r'<tr[^>]*>(.*?)</tr>', re.S)
    cell_re = re.compile(r'<td[^>]*>(.*?)</td>')

    deals = []
    for row_m in row_re.finditer(table):
        cells = cell_re.findall(row_m.group(1))
        cells = [re.sub('<[^>]+>', '', c).strip() for c in cells]
        if len(cells) < 12:
            continue
        time_str = cells[0]
        try:
            t = datetime.strptime(time_str, '%Y.%m.%d %H:%M:%S')
        except ValueError:
            continue
        deal_type = cells[3]
        direction = cells[4]
        balance_str = cells[11].replace(' ', '').replace('\xa0', '')
        try:
            balance = float(balance_str)
        except ValueError:
            continue
        deals.append((t, balance))
    return deals

if __name__ == '__main__':
    all_curves = {}
    for sym in SYMBOLS:
        deals = parse_deals(f'corr_{sym}_utf8.htm')
        all_curves[sym] = deals
        print(f"{sym}: {len(deals)} deal rows, first={deals[0] if deals else None}, last={deals[-1] if deals else None}")

    # Write each as its own CSV (time, balance)
    for sym, deals in all_curves.items():
        with open(f'equity_{sym}.csv', 'w', newline='') as f:
            w = csv.writer(f)
            w.writerow(['time', 'balance'])
            for t, b in deals:
                w.writerow([t.isoformat(), b])
