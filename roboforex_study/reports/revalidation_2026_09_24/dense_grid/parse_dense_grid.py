import re
import os

BASE = os.path.dirname(os.path.abspath(__file__))
SYMBOLS = ['AUDUSD', 'USDCHF', 'CADCHF']

ROW_RE = re.compile(r'<Row>(.*?)</Row>', re.S)
CELL_RE = re.compile(r'<Data ss:Type="\w+">([^<]*)</Data>')

def parse(path):
    with open(path, encoding='utf-8') as f:
        xml = f.read()
    rows = []
    for m in ROW_RE.finditer(xml):
        cells = CELL_RE.findall(m.group(1))
        if len(cells) < 12 or cells[0] == 'Pass':
            continue
        rows.append({
            'profit': float(cells[2]),
            'pf': float(cells[4]),
            'recovery': float(cells[5]),
            'equity_dd': float(cells[8]),
            'trades': int(cells[9]),
            'period': int(float(cells[10])),
            'deviation': float(cells[11]),
        })
    return rows

print(f"{'Symbol':<8}{'Combos':>8}{'EquityDD range':>20}{'PF range':>16}{'Neg-profit combos':>20}{'Default combo (35,2.25) result':>40}")
for sym in SYMBOLS:
    rows = parse(f'{BASE}/dense2_{sym}.xml')
    dds = [r['equity_dd'] for r in rows]
    pfs = [r['pf'] for r in rows]
    neg = [r for r in rows if r['profit'] < 0]
    default = [r for r in rows if r['period'] == 35 and abs(r['deviation'] - 2.25) < 0.001]
    default_str = 'N/A'
    if default:
        d = default[0]
        default_str = f"${d['profit']:.2f}, PF {d['pf']:.2f}, {d['trades']} trades, DD {d['equity_dd']:.2f}%"
    print(f"{sym:<8}{len(rows):>8}{min(dds):>8.2f}-{max(dds):<10.2f}{min(pfs):>7.2f}-{max(pfs):<8.2f}{len(neg):>19}  {default_str}")

print()
for sym in SYMBOLS:
    rows = parse(f'{BASE}/dense2_{sym}.xml')
    neg = [r for r in rows if r['profit'] < 0]
    if neg:
        print(f"{sym} negative-profit combos:")
        for r in neg:
            print(f"  Period={r['period']} Dev={r['deviation']:.2f}  Profit=${r['profit']:.2f}  PF={r['pf']:.2f}  DD={r['equity_dd']:.2f}%")
