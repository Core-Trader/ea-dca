import re
import random

WIDER_DIR = r'C:\Users\vasco\OneDrive\Documentos\000 Trading\001 EA Vault\EA-DCA-V1.0\roboforex_study\reports\wider_window_oos'

def parse_trade_pnls(path):
    """Extract net realized P&L (profit) for each 'out' deal from the Deals table.
    Matches GO_LIVE_VALIDATION_PLAN.md's own methodology: net realized cash impact
    read directly from the Profit column of each closing (out) deal."""
    with open(path, encoding='utf-8') as f:
        html = f.read()
    deals_start = html.find('>Deals<')
    table = html[deals_start:]

    row_re = re.compile(r'<tr[^>]*>(.*?)</tr>', re.S)
    cell_re = re.compile(r'<td[^>]*>(.*?)</td>')

    pnls = []
    for row_m in row_re.finditer(table):
        cells = cell_re.findall(row_m.group(1))
        cells = [re.sub('<[^>]+>', '', c).strip() for c in cells]
        if len(cells) < 12:
            continue
        direction = cells[4]  # 'in' / 'out' / ''
        if direction != 'out':
            continue
        profit_str = cells[10].replace(' ', '').replace('\xa0', '')
        try:
            pnls.append(float(profit_str))
        except ValueError:
            continue
    return pnls

def bootstrap(pnls, n_sims=20000, seed=42):
    rng = random.Random(seed)
    n_trades = len(pnls)
    max_dds = []
    final_balances = []
    for _ in range(n_sims):
        path = [rng.choice(pnls) for _ in range(n_trades)]
        equity = 0.0
        peak = 0.0
        worst_dd = 0.0
        for p in path:
            equity += p
            if equity > peak:
                peak = equity
            dd = peak - equity
            if dd > worst_dd:
                worst_dd = dd
        max_dds.append(worst_dd)
        final_balances.append(equity)
    return max_dds, final_balances

def percentile(sorted_vals, pct):
    idx = int(len(sorted_vals) * pct / 100)
    idx = min(idx, len(sorted_vals) - 1)
    return sorted_vals[idx]

if __name__ == '__main__':
    symbols = ['AUDUSD', 'USDCHF', 'USDCAD', 'CADCHF']
    for sym in symbols:
        path = f'{WIDER_DIR}/wide_{sym}_full_utf8.htm'
        pnls = parse_trade_pnls(path)
        max_dds, finals = bootstrap(pnls)
        max_dds_sorted = sorted(max_dds)
        finals_sorted = sorted(finals)
        neg_count = sum(1 for f in finals if f < 0)

        print(f"=== {sym} ({len(pnls)} trades pooled from full 2024.01-2026.09 window) ===")
        print(f"  Trade P&L: sum={sum(pnls):.2f}  min={min(pnls):.2f}  max={max(pnls):.2f}")
        print(f"  Median max DD:      ${percentile(max_dds_sorted, 50):.2f}")
        print(f"  95th pct max DD:    ${percentile(max_dds_sorted, 95):.2f}")
        print(f"  99th pct max DD:    ${percentile(max_dds_sorted, 99):.2f}")
        print(f"  Worst of {len(max_dds)} paths:  ${max_dds_sorted[-1]:.2f}")
        print(f"  Worst final equity: ${finals_sorted[0]:.2f}")
        print(f"  P(path ends net negative): {neg_count}/{len(finals)} ({100*neg_count/len(finals):.3f}%)")
        print()
