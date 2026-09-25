#!/bin/bash
# Logged single tests (TRL equity logger) for the 6-symbol combined-drawdown check.
# RoboForex terminal, TRL_EA_DCA_CENT_V1_Logged, H4, 2025.03.01-2026.03.01, Model 4.
# Usage: bash run_logged.sh SYM [SYM...]   (aborts if any MT5 terminal is running)
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
INI_WIN="$(cygpath -w "${TEMP:-/tmp}")"
TERM_WIN="C:\RoboForex MT5 Terminal"
TERM_U="/c/RoboForex MT5 Terminal"
COMMON="$(cygpath -u "$APPDATA")/MetaQuotes/Terminal/Common/Files/TRL"
LOG="${HERE}/run_log.txt"
echo "=== started $(date) ===" >> "$LOG"
for sym in "$@"; do
  if powershell -NoProfile -Command "exit [int](-not (Get-Process terminal64 -ErrorAction SilentlyContinue))"; then
    echo "[$(date +%H:%M:%S)] ABORT: terminal64 running before ${sym}" >> "$LOG"; exit 2; fi
  report="TRL_rep_RF_EA_DCA_CENT_V1_Logged_${sym}_1y"
  ini="${INI_WIN}\\${report}.ini"
  cat > "$ini" <<EOF
[Tester]
Login=52010662
Expert=TRL_Corpus\\TRL_EA_DCA_CENT_V1_Logged
ExpertParameters=TRL_${sym}.set
Symbol=${sym}
Period=H4
Model=4
Optimization=0
FromDate=2025.03.01
ToDate=2026.03.01
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
  before=$(ls "$COMMON" 2>/dev/null | sort)
  echo "[$(date +%H:%M:%S)] Launching ${report}" >> "$LOG"
  "${TERM_WIN}\\terminal64.exe" /portable /config:"$ini"
  if [ -f "${TERM_U}/${report}.htm" ]; then
    cp "${TERM_U}/${report}.htm" "${HERE}/"
    echo "[$(date +%H:%M:%S)] OK report ${report}.htm" >> "$LOG"
  else
    echo "[$(date +%H:%M:%S)] *** MISSING REPORT ${report}" >> "$LOG"
  fi
  after=$(ls "$COMMON" 2>/dev/null | sort)
  echo "[$(date +%H:%M:%S)] NEWLOG ${sym} :: $(comm -13 <(echo "$before") <(echo "$after") | tr '\n' ' ')" >> "$LOG"
done
echo "=== finished $(date) ===" >> "$LOG"
