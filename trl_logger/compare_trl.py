import re, os
import sys
R = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), 'results')
COMMON = os.path.join(os.environ['APPDATA'], 'MetaQuotes', 'Terminal', 'Common', 'Files', 'TRL')

def deals(path):
    h = open(path, encoding='utf-8').read()
    t = h[h.find('>Deals<'):]
    rows = []
    for m in re.finditer(r'<tr[^>]*>(.*?)</tr>', t, re.S):
        c = [re.sub('<[^>]+>', '', x).strip() for x in re.findall(r'<td[^>]*>(.*?)</td>', m.group(1))]
        if len(c) >= 12 and re.match(r'\d{4}\.\d\d\.\d\d', c[0]):
            rows.append(tuple(c[:12]))          # time..balance; comment excluded
    return rows

def field(path, label):
    h = open(path, encoding='utf-8').read()
    m = re.search(re.escape(label) + r'.*?<b>([^<]*)</b>', h, re.S)
    return m.group(1).strip() if m else 'N/A'

def settings(path):
    h = open(path, encoding='utf-8').read()
    per = re.search(r'H4 \(([^)]*)\)', h)
    return per.group(1) if per else '?', 'InpBBAppliedPrice=2' in h

# map report -> new log file from batch log
newlog = {}
for line in open(os.path.join(R, 'batch_log.txt'), encoding='utf-8'):
    m = re.search(r'NEWLOG (\S+) :: (.*)', line)
    if m: newlog[m.group(1)] = m.group(2).split()

print(f"{'pair':<44}{'deals C/L':>11}{'same':>6}  {'final bal C / L':<24}{'window':<26}log")
for term in ['RF', 'FTMO']:
    for ea in ['EA_DCA_CENT_V1', 'DCA_EA']:
        for tag in ['USDCHF_1y', 'EURUSD_1y', 'USDCHF_full']:
            c = os.path.join(R, f'TRL_rep_{term}_{ea}_Control_{tag}_utf8.htm')
            l = os.path.join(R, f'TRL_rep_{term}_{ea}_Logged_{tag}_utf8.htm')
            name = f'{term} {ea} {tag}'
            if not (os.path.exists(c) and os.path.exists(l)):
                print(f'{name:<44} MISSING REPORT(S)'); continue
            dc, dl = deals(c), deals(l)
            bc = dc[-1][11] if dc else 'N/A'; bl = dl[-1][11] if dl else 'N/A'
            same = dc == dl and bc == bl
            win, ok_c = settings(c); _, ok_l = settings(l)
            logs = newlog.get(f'TRL_rep_{term}_{ea}_Logged_{tag}', [])
            hdr = ''
            if logs:
                lp = os.path.join(COMMON, logs[-1])
                head = open(lp, encoding='utf-8', errors='replace').read(600)
                fmt = re.search(r'# format: (\S+)', head); ver = re.search(r'# logger_version: (\S+)', head)
                hdr = f"{logs[-1]} [{fmt.group(1) if fmt else '?'} v{ver.group(1) if ver else '?'}]"
            else:
                hdr = 'NO LOG'
            flag = '' if (ok_c and ok_l) else ' (settings?)'
            print(f"{name:<44}{len(dc):>5}/{len(dl):<5}{'YES' if same else 'NO':>6}  {bc+' / '+bl:<24}{win:<26}{hdr}{flag}")
