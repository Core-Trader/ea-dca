import re
def ex(p):
    h=open(p,encoding='utf-8').read()
    f=lambda l:(re.search(re.escape(l)+r'.*?<b>([^<]*)</b>',h,re.S) or [None,'N/A'])[1].strip()
    return [f('Total Net Profit:'),f('Profit Factor:'),f('Recovery Factor:'),f('Equity Drawdown Maximal:'),f('Total Trades:')]
print(f"{'Run':<16}{'Profit':>10}{'PF':>7}{'Recov':>7}{'EquityDD':>18}{'Trades':>8}")
for r in ['USDCHF_full','USDCHF_oosA','AUDUSD_full','CADCHF_full']:
    d=ex(f'm4_{r}_utf8.htm'); print(f"{r:<16}{d[0]:>10}{d[1]:>7}{d[2]:>7}{d[3]:>18}{d[4]:>8}")
