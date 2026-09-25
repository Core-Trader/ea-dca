# Builds TRL_<name>_Logged.mq5 (original + the 4 "// TRL" lines) and TRL_<name>_Control.mq5
# (byte-identical copy), preserving the source file's line endings. Line args are 1-based and
# asserted: <include line> <return(INIT_SUCCEEDED) line> <OnDeinit "{" line> <OnTick "{" line>.
# Usage: py insert_trl.py <src.mq5> <out_dir> <name> <inc> <init> <deinit_brace> <ontick_brace>
import sys, shutil
src, out_dir, name, inc, init, dein, tick = sys.argv[1], sys.argv[2], sys.argv[3], *map(int, sys.argv[4:8])
data = open(src, 'rb').read()
nl = b'\r\n' if b'\r\n' in data else b'\n'
lines = data.split(nl)
L = lambda s: s.encode('utf-8')
def chk(n, expect):
    assert expect in lines[n-1].decode('utf-8', 'replace'), (n, lines[n-1])
chk(inc, '#include'); chk(init, 'return(INIT_SUCCEEDED)'); chk(dein - 1, 'OnDeinit'); chk(dein, '{'); chk(tick - 1, 'OnTick'); chk(tick, '{')
# bottom-up insertions (1-based line numbers)
ins = sorted([
    (tick, 'after',  '   TrlEquityOnTick();                                // TRL'),
    (dein, 'after',  '   TrlEquityFinish();                                // TRL'),
    (init, 'before', '   TrlEquityInit();                                  // TRL'),
    (inc,  'after',  '#include <TRL_EquityLogger.mqh>                      // TRL'),
], key=lambda t: t[0], reverse=True)
for n, where, text in ins:
    lines.insert(n if where == 'after' else n - 1, L(text))
open(f'{out_dir}/TRL_{name}_Logged.mq5', 'wb').write(nl.join(lines))
shutil.copyfile(src, f'{out_dir}/TRL_{name}_Control.mq5')
print(name, 'line ending', repr(nl))
