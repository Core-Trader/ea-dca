#!/bin/bash
# TP/SL phase 2: DCA_EA_TPSL_Forensic on RoboForex, 6 portfolio symbols x 5 entry-filter
# variants (sets/tpsl_p2_*.set, all derived from corrected test_B), H4,
# 2024.01.01-2026.09.19, Model 4, $15,000, 1:1000. Copies each report and each
# per-trade CSV out immediately (the Tester agent's Files folder is wiped between
# launches). Aborts if an MT5 terminal is running. Usage: bash run_phase2.sh [SYM ...]
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
INI_WIN="$(cygpath -w "${TEMP:-/tmp}")"
TERM_WIN="C:\RoboForex MT5 Terminal"
TERM_U="/c/RoboForex MT5 Terminal"
OUT="${HERE}/runs"; mkdir -p "$OUT"
LOG="${HERE}/run_log.txt"
SYMS=("$@"); [ ${#SYMS[@]} -eq 0 ] && SYMS=(EURUSD GBPUSD USDJPY AUDUSD USDCHF CADCHF)
echo "=== started $(date) : ${SYMS[*]} ===" >> "$LOG"
for sym in "${SYMS[@]}"; do
  for v in base matrend marev htfd1 bbwidth; do
    report="tpsl_p2_${sym}_${v}"
    [ -f "${OUT}/${report}_utf8.htm" ] && { echo "[$(date +%H:%M:%S)] skip ${report} (done)" >> "$LOG"; continue; }
    if powershell -NoProfile -Command "exit [int](-not (Get-Process terminal64 -ErrorAction SilentlyContinue))"; then
      echo "[$(date +%H:%M:%S)] ABORT: terminal64 running before ${report}" >> "$LOG"; exit 2; fi
    ini="${INI_WIN}\\${report}.ini"
    cat > "$ini" <<EOF
[Tester]
Login=52010662
Expert=EA-DCA-V1.0\\DCA_EA_TPSL_Forensic
ExpertParameters=tpsl_p2_${v}.set
Symbol=${sym}
Period=H4
Model=4
Optimization=0
FromDate=2024.01.01
ToDate=2026.09.19
ForwardMode=0
Deposit=15000
Currency=USD
Leverage=1000
ExecutionMode=0
Report=${report}
ReplaceReport=1
ShutdownTerminal=1
Visual=0
EOF
    echo "[$(date +%H:%M:%S)] Launching ${report}" >> "$LOG"
    "${TERM_WIN}\\terminal64.exe" /portable /config:"$ini"
    if [ -f "${TERM_U}/${report}.htm" ]; then
      iconv -f UTF-16LE -t UTF-8 "${TERM_U}/${report}.htm" > "${OUT}/${report}_utf8.htm"
      echo "[$(date +%H:%M:%S)] OK report ${report}" >> "$LOG"
    else
      echo "[$(date +%H:%M:%S)] *** MISSING REPORT ${report}" >> "$LOG"
    fi
    found=0
    for csv in "${TERM_U}"/Tester/Agent-*/MQL5/Files/tpsl_forensic_*.csv; do
      [ -f "$csv" ] || continue; cp "$csv" "${OUT}/${report}.csv"; found=1
    done
    [ "$found" = 1 ] && echo "[$(date +%H:%M:%S)] OK csv ${report}.csv" >> "$LOG" || echo "[$(date +%H:%M:%S)] *** NO CSV ${report}" >> "$LOG"
  done
done
echo "=== finished $(date) ===" >> "$LOG"
