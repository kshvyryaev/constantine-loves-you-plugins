# Install OpenMontage's Python dependencies into the existing .venv, in a fixed order.
# Stops at the first failing install or the import check; `pip check` never stops the run.
# A "WinError 32" (file locked, usually antivirus) is retried once per step.
# Usage: install_python_deps.ps1 INSTALL_DIR
# Output, in this order:
#   STATUS: OK | FAILED
#   FAILED_COMMAND: <command or none>
#   NOTES: <pip check findings or none>
#   LAST_ERROR_LINES: <none, or the last 20 output lines on the following lines>
# Exit code 0 only for STATUS: OK. Never reads .env.
param([Parameter(Mandatory = $true, Position = 0)][string]$InstallDir)

. "$PSScriptRoot\common.ps1"
Update-Path
$dir = Expand-UserPath $InstallDir
$py = Join-Path $dir ".venv\Scripts\python.exe"
$env:PYTHONUTF8 = "1"

function Report([string]$Status, [string]$Failed, [string]$Notes, [string]$Output) {
    "STATUS: $Status"
    "FAILED_COMMAND: $Failed"
    "NOTES: $Notes"
    if ($Output) {
        "LAST_ERROR_LINES:"
        $Output -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -Last 20
    } else {
        "LAST_ERROR_LINES: none"
    }
}

if (-not (Test-Path -LiteralPath $py)) { Report "FAILED" "none" "no .venv in $dir" ""; exit 1 }

$installs = @(
    "-m pip install -r requirements.txt",
    "-m pip install piper-tts",
    "-m pip install faster-whisper",
    "-m pip install whisperx",
    "-m pip install `"av<19`""
)
foreach ($step in $installs) {
    $r = Invoke-Bounded 3600 $py $step $dir
    if ($r.Code -ne 0 -and ($r.Out + $r.Err) -match "WinError 32") { $r = Invoke-Bounded 3600 $py $step $dir }
    if ($r.Code -ne 0) { Report "FAILED" "python $step" "none" ($r.Out + "`n" + $r.Err); exit 1 }
}

$check = Invoke-Bounded 300 $py "-m pip check" $dir
$notes = "none"
if ($check.Code -ne 0) {
    $notes = (($check.Out + "`n" + $check.Err) -split "`r?`n" | Where-Object { $_.Trim() }) -join " | "
}

$imports = "-c `"import faster_whisper, whisperx, piper, fastapi`""
$r = Invoke-Bounded 300 $py $imports $dir
if ($r.Code -ne 0) { Report "FAILED" "python $imports" $notes ($r.Out + "`n" + $r.Err); exit 1 }

Report "OK" "none" $notes ""
exit 0
