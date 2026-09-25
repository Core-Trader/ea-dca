#!/bin/bash
# Logged-vs-control verification for the TRL equity logger (Git Bash).
# Runs every Control/Logged pair as Model 4 single tests on both terminals,
# then records each report and the equity log each Logged run created.
# Needs: TRL_<EA>_{Control,Logged}.ex5 compiled in <terminal>\MQL5\Experts\TRL_Corpus\
# and TRL_<SYMBOL>.set in <terminal>\MQL5\Profiles\Tester\ (see PROJECT_HANDOFF.md §2E).
# Aborts if any MT5 terminal is running. Then: py trl_logger/compare_trl.py
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="${HERE}/results"
INI_WIN="$(cygpath -w "${TEMP:-/tmp}")"          # .ini path must be all-backslash (CLAUDE.md)
COMMON="$(cygpath -u "$APPDATA")/MetaQuotes/Terminal/Common/Files/TRL"
LOG="${OUT}/batch_log.txt"
mkdir -p "$OUT"
echo "=== TRL batch started $(date) ===" > "$LOG"

mt5_running() { powershell -NoProfile -Command "exit [int](-not (Get-Process terminal64 -ErrorAction SilentlyContinue))"; }

run_one() {
  local term="$1" termdir="$2" login="$3" deposit="$4" lev="$5" ea="$6" variant="$7" sym="$8" from="$9" to="${10}" tag="${11}"
  local report="TRL_rep_${term}_${ea}_${variant}_${tag}"
  if mt5_running; then echo "[$(date +%H:%M:%S)] ABORT: terminal64 running before ${report}" >> "$LOG"; exit 2; fi
  local ini="${INI_WIN}\\${report}.ini"
  cat > "$ini" <<EOF
[Tester]
Login=${login}
Expert=TRL_Corpus\\TRL_${ea}_${variant}
ExpertParameters=TRL_${sym}.set
Symbol=${sym}
Period=H4
Model=4
Optimization=0
FromDate=${from}
ToDate=${to}
ForwardMode=0
Deposit=${deposit}
Currency=USD
Leverage=${lev}
ExecutionMode=0
Report=${report}
ReplaceReport=1
ShutdownTerminal=1
Visual=0
EOF
  local before; before=$(ls "$COMMON" 2>/dev/null | sort)
  echo "[$(date +%H:%M:%S)] Launching ${report}" >> "$LOG"
  "${termdir}\\terminal64.exe" /portable /config:"$ini"
  local tdir="${termdir//\\//}"
  if [ -f "${tdir}/${report}.htm" ]; then
    iconv -f UTF-16LE -t UTF-8 "${tdir}/${report}.htm" > "${OUT}/${report}_utf8.htm" 2>/dev/null
    echo "[$(date +%H:%M:%S)] OK report ${tdir}/${report}.htm" >> "$LOG"
  else
    echo "[$(date +%H:%M:%S)] *** MISSING REPORT ${report}" >> "$LOG"
  fi
  local after; after=$(ls "$COMMON" 2>/dev/null | sort)
  local new; new=$(comm -13 <(echo "$before") <(echo "$after") | tr '\n' ' ')
  echo "[$(date +%H:%M:%S)] NEWLOG ${report} :: ${new}" >> "$LOG"
}

for T in "RF|C:\RoboForex MT5 Terminal|52010662|15000|1000" "FTMO|C:\FTMO Global Markets MT5 Terminal|540291482|100000|30"; do
  IFS='|' read -r term termdir login dep lev <<< "$T"
  for ea in EA_DCA_CENT_V1 DCA_EA; do
    for setup in "USDCHF|2025.03.01|2026.03.01|USDCHF_1y" "EURUSD|2025.03.01|2026.03.01|EURUSD_1y" "USDCHF|2024.01.01|2026.09.19|USDCHF_full"; do
      IFS='|' read -r sym from to tag <<< "$setup"
      for variant in Control Logged; do
        run_one "$term" "$termdir" "$login" "$dep" "$lev" "$ea" "$variant" "$sym" "$from" "$to" "$tag"
      done
    done
  done
done
echo "=== TRL batch finished $(date) ===" >> "$LOG"
