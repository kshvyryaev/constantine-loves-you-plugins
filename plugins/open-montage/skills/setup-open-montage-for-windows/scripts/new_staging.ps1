# Create the private key staging file in a fixed per-user folder, so a later session finds leftovers.
# Folder and file are restricted to the current user.
# Usage: new_staging.ps1
# Output: "STAGING <path>" | "ERROR: ..." (exit 2).

. "$PSScriptRoot\common.ps1"

$dir = Join-Path $env:LOCALAPPDATA "open-montage"
New-Item -ItemType Directory -Force -Path $dir | Out-Null
if (-not (Protect-Path $dir)) { "ERROR: could not restrict $dir to the current user"; exit 2 }

$path = Join-Path $dir ("keys." + [IO.Path]::GetRandomFileName().Replace(".", ""))
Write-Utf8Lines $path @()
if (-not (Protect-Path $path)) { Remove-Item -LiteralPath $path -Force; "ERROR: could not restrict $path to the current user"; exit 2 }
"STAGING $path"
