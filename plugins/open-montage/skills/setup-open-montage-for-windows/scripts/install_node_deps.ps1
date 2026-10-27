# Install OpenMontage's Node.js dependencies (Remotion) and warm the HyperFrames npx cache.
# npm install falls back to `npx --yes npm install` on ERR_INVALID_ARG_TYPE, as OpenMontage's README advises.
# A failed HyperFrames fetch is only a note: it is fetched again on first render.
# Usage: install_node_deps.ps1 INSTALL_DIR
# Output, in this order:
#   STATUS: OK | FAILED
#   FAILED_COMMAND: <command or none>
#   HYPERFRAMES_VERSION: <version or none>
#   NOTES: <fallback used, HyperFrames failure, files changed in the clone, or none>
#   LAST_ERROR_LINES: <none, or the last 20 output lines on the following lines>
# Exit code 0 only for STATUS: OK. Never reads .env.
param([Parameter(Mandatory = $true, Position = 0)][string]$InstallDir)

. "$PSScriptRoot\common.ps1"
Update-Path
$dir = Expand-UserPath $InstallDir
$composer = Join-Path $dir "remotion-composer"
$notes = @()
$hfVersion = "none"

function Report([string]$Status, [string]$Failed, [string]$Output) {
    "STATUS: $Status"
    "FAILED_COMMAND: $Failed"
    "HYPERFRAMES_VERSION: $hfVersion"
    if ($notes.Count -gt 0) { "NOTES: " + ($notes -join " | ") } else { "NOTES: none" }
    if ($Output) {
        "LAST_ERROR_LINES:"
        $Output -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -Last 20
    } else {
        "LAST_ERROR_LINES: none"
    }
}

# Run a .cmd shim through cmd.exe, which CreateProcess needs for batch files.
function Invoke-Cmd([int]$Seconds, [string]$Shim, [string]$Arguments, [string]$WorkDir) {
    return Invoke-Bounded $Seconds "cmd.exe" "/d /c `"`"$Shim`" $Arguments`"" $WorkDir
}

$npm = Find-Command "npm.cmd"
$npx = Find-Command "npx.cmd"
if (-not $npm -or -not $npx) { Report "FAILED" "none" "npm.cmd or npx.cmd not found: Node.js is missing"; exit 1 }
if (-not (Test-Path -LiteralPath $composer)) { Report "FAILED" "none" "no remotion-composer folder in $dir"; exit 1 }

$r = Invoke-Cmd 1800 $npm "install" $composer
if ($r.Code -ne 0 -and ($r.Out + $r.Err) -match "ERR_INVALID_ARG_TYPE") {
    $notes += "npm install hit ERR_INVALID_ARG_TYPE; used npx --yes npm install"
    $r = Invoke-Cmd 1800 $npx "--yes npm install" $composer
}
if ($r.Code -ne 0) { Report "FAILED" "npm.cmd install (remotion-composer)" ($r.Out + "`n" + $r.Err); exit 1 }

$hf = Invoke-Cmd 300 $npx "--yes hyperframes --version" $dir
if ($hf.Code -eq 0 -and $hf.Out -match '(\d+(\.\d+)+)') {
    $hfVersion = $Matches[1]
} else {
    $notes += "npx hyperframes --version failed; HyperFrames is fetched again on first render"
}

# npm install may rewrite a tracked lockfile; a dirty clone blocks the next git pull --ff-only.
$changed = @(& git -C $dir status --short 2>$null | Where-Object { $_.Trim() })
if ($changed.Count -gt 0) { $notes += "changed in clone: " + (($changed | ForEach-Object { $_.Trim() }) -join ", ") }

Report "OK" "none" ""
exit 0
