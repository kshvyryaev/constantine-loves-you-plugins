# Install the missing toolchain with winget, one package at a time (winget runs one install at a time).
# Git, Node.js and the Visual C++ runtime install machine-wide: Windows shows a UAC prompt for each.
# Usage: install_tools.ps1 [-CheckOnly]
# Output: one line per tool, then a result line:
#   "PRESENT <tool> <detail>" | "INSTALLED <tool> <detail>" | "MISSING <tool>" (with -CheckOnly)
#   "OLD node <version> (need v22+)" (never replaced automatically) | "FAILED <tool> winget exit <code>"
#   followed by up to 10 "LOG <line>" lines | "NO_WINGET" (exit 2)
#   "RESULT OK" | "RESULT INCOMPLETE" (exit 1)
param([switch]$CheckOnly)

. "$PSScriptRoot\common.ps1"
Update-Path
$arch = Get-NativeArch

function Test-Tool([string]$Name) {
    switch ($Name) {
        "vcredist" { if (Test-VCRedist $arch) { return "Visual C++ runtime ($arch)" } else { return "" } }
        "node" {
            $major = Get-NodeMajor
            if ($major -ge 22) { return (& (Find-Command "node.exe") --version | Out-String).Trim() } else { return "" }
        }
        default {
            $path = Find-Command "$Name.exe"
            return $path
        }
    }
}

$tools = [ordered]@{
    "git"      = "Git.Git"
    "uv"       = "astral-sh.uv"
    "ffmpeg"   = "Gyan.FFmpeg"
    "node"     = "OpenJS.NodeJS.LTS"
    "vcredist" = "Microsoft.VCRedist.2015+.$arch"
}

$hasWinget = [bool](Find-Command "winget.exe")
$complete = $true
foreach ($name in $tools.Keys) {
    $found = Test-Tool $name
    if ($found) { "PRESENT $name $found"; continue }
    if ($name -eq "node" -and (Get-NodeMajor) -gt 0) {
        "OLD node " + (& (Find-Command "node.exe") --version | Out-String).Trim() + " (need v22+)"
        $complete = $false
        continue
    }
    if ($CheckOnly) { "MISSING $name"; $complete = $false; continue }
    if (-not $hasWinget) { "NO_WINGET"; exit 2 }

    $log = & winget.exe install --id $tools[$name] --exact --source winget --silent --accept-package-agreements --accept-source-agreements --disable-interactivity 2>&1 | Out-String
    $code = $LASTEXITCODE
    Update-Path
    $found = Test-Tool $name
    if ($found) {
        "INSTALLED $name $found"
    } else {
        "FAILED $name winget exit $code"
        $log -split "`r?`n" | Where-Object { $_.Trim() -and $_ -notmatch '^[\s\-\\|/]+$' } | Select-Object -Last 10 | ForEach-Object { "LOG $($_.Trim())" }
        $complete = $false
    }
}

if ($complete) { "RESULT OK"; exit 0 } else { "RESULT INCOMPLETE"; exit 1 }
