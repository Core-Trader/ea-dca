import csv

with open('eurusd_bb_grid.csv') as f:
    reader = csv.DictReader(f)
    rows = list(reader)

periods = sorted({int(float(r['InpBBPeriod'])) for r in rows})
devs = sorted({float(r['InpBBDeviation']) for r in rows})

def grid(metric, fmt):
    lookup = {}
    for r in rows:
        key = (int(float(r['InpBBPeriod'])), float(r['InpBBDeviation']))
        lookup[key] = r[metric]
    print()
    print("===", metric, "===")
    header = "Period/Dev  " + "  ".join(fmt.format(d) for d in devs)
    print(header)
    for p in periods:
        line = str(p).rjust(10) + "  "
        for d in devs:
            v = lookup.get((p, d))
            if v is None:
                line += "N/A".rjust(7) + "  "
            else:
                line += fmt.format(float(v)).rjust(7) + "  "
        print(line)

grid('Profit', "{:.0f}")
grid('Profit Factor', "{:.2f}")
grid('Equity DD %', "{:.2f}")
grid('Trades', "{:.0f}")

sr = sorted(rows, key=lambda r: -float(r['Profit']))
print()
print("=== TOP 10 by Profit ===")
print("Period  Dev  Profit    PF    Recovery  Sharpe  DD%   Trades")
for r in sr[:10]:
    print(f"{int(float(r['InpBBPeriod'])):>6} {float(r['InpBBDeviation']):>5.2f} {float(r['Profit']):>9.2f} {float(r['Profit Factor']):>6.2f} {float(r['Recovery Factor']):>9.2f} {float(r['Sharpe Ratio']):>7.2f} {float(r['Equity DD %']):>6.2f} {int(float(r['Trades'])):>7}")

print()
print("=== BOTTOM 5 by Profit ===")
for r in sr[-5:]:
    print(f"{int(float(r['InpBBPeriod'])):>6} {float(r['InpBBDeviation']):>5.2f} {float(r['Profit']):>9.2f} {float(r['Profit Factor']):>6.2f} {float(r['Recovery Factor']):>9.2f} {float(r['Sharpe Ratio']):>7.2f} {float(r['Equity DD %']):>6.2f} {int(float(r['Trades'])):>7}")
