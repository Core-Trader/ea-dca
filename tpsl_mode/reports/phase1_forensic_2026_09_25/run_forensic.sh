#!/bin/bash
# TP/SL phase 1: DCA_EA_TPSL_Forensic on FTMO, EURUSD H4, 2025.01.01-2026.01.22, Model 4.
# Runs test_B as stored (stale BB/MA applied price) and the price-corrected copy.
# Each run's per-trade CSV (MFE/MAE, exit comment) is copied out immediately:
# the Tester agent's MQL5\Files folder is wiped between launches.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
INI_WIN="$(cygpath -w "${TEMP:-/tmp}")"
TERM_WIN="C:\FTMO Global Markets MT5 Terminal"
TERM_U="/c/FTMO Global Markets MT5 Terminal"
LOG="${HERE}/run_log.txt"
echo "=== started $(date) ===" >> "$LOG"
for variant in "stale|test_B_fixed_pips" "pricefix|test_B_fixed_pips_pricefix"; do
  IFS='|' read -r tag setname <<< "$variant"
  if powershell -NoProfile -Command "exit [int](-not (Get-Process terminal64 -ErrorAction SilentlyContinue))"; then
    echo "[$(date +%H:%M:%S)] ABORT: terminal64 running before ${tag}" >> "$LOG"; exit 2; fi
  report="tpsl_forensic_B_${tag}"
  ini="${INI_WIN}\\${report}.ini"
  cat > "$ini" <<EOF
[Tester]
Login=540291482
Expert=EA-DCA-V1.0\\DCA_EA_TPSL_Forensic
ExpertParameters=${setname}.set
Symbol=EURUSD
Period=H4
Model=4
Optimization=0
FromDate=2025.01.01
ToDate=2026.01.22
ForwardMode=0
Deposit=100000
Currency=USD
Leverage=30
ExecutionMode=0
Report=${report}
ReplaceReport=1
ShutdownTerminal=1
Visual=0
EOF
  echo "[$(date +%H:%M:%S)] Launching ${report}" >> "$LOG"
  "${TERM_WIN}\\terminal64.exe" /portable /config:"$ini"
  if [ -f "${TERM_U}/${report}.htm" ]; then
    iconv -f UTF-16LE -t UTF-8 "${TERM_U}/${report}.htm" > "${HERE}/${report}_utf8.htm"
    echo "[$(date +%H:%M:%S)] OK report ${report}" >> "$LOG"
  else
    echo "[$(date +%H:%M:%S)] *** MISSING REPORT ${report}" >> "$LOG"
  fi
  found=0
  for csv in "${TERM_U}"/Tester/Agent-*/MQL5/Files/tpsl_forensic_*.csv; do
    [ -f "$csv" ] || continue
    cp "$csv" "${HERE}/${tag}_$(basename "$csv")"; found=1
    echo "[$(date +%H:%M:%S)] OK csv ${tag}_$(basename "$csv")" >> "$LOG"
  done
  [ "$found" = 1 ] || echo "[$(date +%H:%M:%S)] *** NO FORENSIC CSV for ${tag}" >> "$LOG"
done
echo "=== finished $(date) ===" >> "$LOG"
