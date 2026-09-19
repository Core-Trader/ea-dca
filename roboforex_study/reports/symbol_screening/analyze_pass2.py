import csv

symbols = ['AUDUSD', 'USDCHF', 'NZDUSD', 'EURJPY', 'EURCAD', 'USDCAD', 'AUDJPY', 'GBPJPY', 'AUDCHF', 'CADCHF']

# Load Pass 1 defaults
with open('pass1_default_forexall_2025-03_2026-03.csv') as f:
    pass1 = {r['Symbol']: r for r in csv.DictReader(f)}

print(f"{'Symbol':<8}{'DefProfit':>10}{'DefPF':>7}{'DefRec':>8}{'OptProfit':>11}{'OptPF':>7}{'OptRec':>8}{'OptDD%':>8}{'Trades':>8}{'#combos':>9}{'Median':>9}{'2ndBest':>9}")
for sym in symbols:
    with open(f'pass2_genetic_{sym}.csv') as f:
        rows = list(csv.DictReader(f))
    rows_sorted = sorted(rows, key=lambda r: -float(r['Profit']))
    best = rows_sorted[0]
    second = rows_sorted[1] if len(rows_sorted) > 1 else None
    profits = sorted(float(r['Profit']) for r in rows)
    median = profits[len(profits)//2]
    d = pass1[sym]
    print(f"{sym:<8}{float(d['Profit']):>10.2f}{float(d['Profit Factor']):>7.2f}{float(d['Recovery Factor']):>8.2f}"
          f"{float(best['Profit']):>11.2f}{float(best['Profit Factor']):>7.2f}{float(best['Recovery Factor']):>8.2f}"
          f"{float(best['Equity DD %']):>8.2f}{int(float(best['Trades'])):>8}{len(rows):>9}{median:>9.2f}"
          f"{(float(second['Profit']) if second else 0):>9.2f}")
    # print best combo's parameters
    param_keys = [k for k in best.keys() if k.startswith('Inp')]
    params = {k: best[k] for k in param_keys}
    print(f"    best params: {params}")
