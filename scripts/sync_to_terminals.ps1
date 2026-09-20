# Syncs src/experts/*.mq5 and src/indicators/*.mq5 from this repo to both MT5
# terminals' EA-DCA-V1.0 subfolders, PLUS the bare-named root-level copies of
# the three indicators loaded via iCustom() with no folder qualifier
# (QMP Filter, QQE Adv, MACD_Platinum -- see CLAUDE.md's "Indicator resolution"
# section for why the root copies exist and must be kept in sync separately).
#
# Run this after ANY change to src/experts/ or src/indicators/, before
# compiling or backtesting on either terminal. Neither terminal is symlinked
# to this repo -- both are plain, independently-maintained copies, and will
# silently run stale code if this isn't run.
#
# Usage: powershell -File scripts\sync_to_terminals.ps1

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot

$Terminals = @(
    "C:\FTMO Global Markets MT5 Terminal",
    "C:\RoboForex MT5 Terminal"
)

# Bare-name root copies: repo filename -> the space/underscore name the
# terminal's Indicators root actually needs (matching each iCustom() call
# string exactly). MACD_Platinum keeps its underscore; the other two don't.
$RootIndicatorRenames = @{
    "QMP_Filter.mq5" = "QMP Filter.mq5"
    "QQE_Adv.mq5"    = "QQE Adv.mq5"
    "MACD_Platinum.mq5" = "MACD_Platinum.mq5"
}

foreach ($terminal in $Terminals) {
    if (-not (Test-Path $terminal)) {
        Write-Host "SKIP: $terminal not found on this machine." -ForegroundColor Yellow
        continue
    }

    Write-Host "`n=== $terminal ===" -ForegroundColor Cyan

    $expertsDir    = Join-Path $terminal "MQL5\Experts\EA-DCA-V1.0"
    $indicatorsDir = Join-Path $terminal "MQL5\Indicators\EA-DCA-V1.0"
    $indicatorsRoot = Join-Path $terminal "MQL5\Indicators"

    foreach ($d in @($expertsDir, $indicatorsDir)) {
        if ((Test-Path $d) -and (Get-Item $d -Force).LinkType) {
            throw "$d is still a symlink -- this script assumes plain-copy terminals only. Run the migration step first, or fix this path manually."
        }
        New-Item -ItemType Directory -Path $d -Force | Out-Null
    }

    Copy-Item (Join-Path $RepoRoot "src\experts\*.mq5") -Destination $expertsDir -Force
    Write-Host "  Synced src\experts\*.mq5 -> $expertsDir"

    Copy-Item (Join-Path $RepoRoot "src\indicators\*.mq5") -Destination $indicatorsDir -Force
    Write-Host "  Synced src\indicators\*.mq5 -> $indicatorsDir"

    foreach ($srcName in $RootIndicatorRenames.Keys) {
        $srcPath = Join-Path $RepoRoot "src\indicators\$srcName"
        if (-not (Test-Path $srcPath)) {
            Write-Host "  SKIP root copy: $srcName not found in repo" -ForegroundColor Yellow
            continue
        }
        $destName = $RootIndicatorRenames[$srcName]
        $destPath = Join-Path $indicatorsRoot $destName
        Copy-Item $srcPath -Destination $destPath -Force
        Write-Host "  Synced $srcName -> Indicators root as `"$destName`""
    }
}

Write-Host "`nDone. Recompile through each terminal's MetaEditor to regenerate .ex5 binaries -- this script only ever touches .mq5 source." -ForegroundColor Cyan
