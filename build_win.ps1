# build_win.ps1 - Windows release build helper (PowerShell entry point)
#
# This is a THIN WRAPPER. All build logic lives in build_windows.bat, which is
# the single source of truth, so the two entry points can never drift apart.
#
#   .\build_win.ps1                 normal build
#   .\build_win.ps1 -Clean          flutter clean first
#   .\build_win.ps1 -Open           open the output folder on success
#
# Output is streamed to the console and tee'd into build_win.log.

[CmdletBinding()]
param(
    [switch]$Clean,
    [switch]$Open
)

$project = Split-Path -Parent $MyInvocation.MyCommand.Path
$bat     = Join-Path $project 'build_windows.bat'
$log     = Join-Path $project 'build_win.log'

if (-not (Test-Path -LiteralPath $bat)) {
    Write-Host "[ERROR] build_windows.bat not found next to this script: $bat" -ForegroundColor Red
    Read-Host 'Press Enter to close'
    exit 1
}

$argList = @()
if ($Clean) { $argList += '--clean' }
if ($Open)  { $argList += '--open' }

& $bat @argList 2>&1 | Tee-Object -FilePath $log
$code = $LASTEXITCODE

Write-Host ""
Write-Host ("exe : " + (Join-Path $project 'build\windows\x64\runner\Release\qingmang_weiji.exe'))
Write-Host ("log : " + $log)
Write-Host ("exit: " + $code)
exit $code
