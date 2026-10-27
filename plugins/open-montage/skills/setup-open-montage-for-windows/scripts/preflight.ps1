# Decide whether this PC can run the setup, and classify an install folder.
# Usage:
#   preflight.ps1                    system check
#   preflight.ps1 -Keep STAGING      system check that does not list the current STAGING file as stale
#   preflight.ps1 -Folder PATH       classify PATH for Step 5
# System output lines: "STATUS OK|LOW_DISK <reason>|STOP <reason>", "OS Windows <10|11> build <n>",
#   "ARCH x64|arm64", "WINGET yes|no", "VCREDIST yes|no", "LONGPATHS yes|no",
#   "TOOL <name> <path> [version]", "STALE_STAGING <path>" (one per leftover key file).
# Folder output: "FOLDER EMPTY|CLONE|FOREIGN <path>", "VENV <python version|none>" for a clone, and
#   "DISK OK|LOW <n> GB free" or "DISK UNKNOWN" for the drive PATH is on.
# A new install needs 10 GB free on the drive of the install folder.
param([string]$Folder, [string]$Keep)

. "$PSScriptRoot\common.ps1"
Update-Path
$needGb = 10

if ($Folder) {
    $dir = Expand-UserPath $Folder
    $empty = $true
    if (Test-Path -LiteralPath $dir) { $empty = -not (Get-ChildItem -LiteralPath $dir -Force | Select-Object -First 1) }
    $gitConfig = Join-Path $dir ".git\config"
    if ($empty) {
        "FOLDER EMPTY $dir"
    } elseif ((Test-Path -LiteralPath $gitConfig) -and (Select-String -LiteralPath $gitConfig -Pattern "calesthio/OpenMontage" -SimpleMatch -Quiet)) {
        "FOLDER CLONE $dir"
        $py = Join-Path $dir ".venv\Scripts\python.exe"
        if (Test-Path -LiteralPath $py) { "VENV " + (& $py --version 2>&1 | Out-String).Trim() } else { "VENV none" }
    } else {
        "FOLDER FOREIGN $dir"
    }
    $gb = Get-FreeGb $dir
    if ($gb -lt 0) { "DISK UNKNOWN" } elseif ($gb -lt $needGb) { "DISK LOW $gb GB free" } else { "DISK OK $gb GB free" }
    exit 0
}

$build = [Environment]::OSVersion.Version.Build
$arch = Get-NativeArch
$reason = ""; $low = ""
if ([Environment]::OSVersion.Platform -ne "Win32NT") {
    $reason = "not Windows"
} elseif ($build -lt 17763) {
    $reason = "Windows build $build is older than Windows 10 1809 (17763), the oldest with winget"
} elseif ($arch -ne "x64" -and $arch -ne "arm64") {
    $reason = "32-bit Windows ($arch) is not supported"
} else {
    $gb = Get-FreeGb $env:USERPROFILE
    if ($gb -ge 0 -and $gb -lt $needGb) { $low = "only $gb GB free on the user profile's drive, a new install needs $needGb GB" }
}
if ($reason) { "STATUS STOP $reason" } elseif ($low) { "STATUS LOW_DISK $low" } else { "STATUS OK" }

$edition = "10"
if ($build -ge 22000) { $edition = "11" }
"OS Windows $edition build $build"
"ARCH $arch"
if (Find-Command "winget.exe") { "WINGET yes" } else { "WINGET no" }
if (Test-VCRedist $arch) { "VCREDIST yes" } else { "VCREDIST no" }
$lp = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -ErrorAction SilentlyContinue).LongPathsEnabled
if ($lp -eq 1) { "LONGPATHS yes" } else { "LONGPATHS no" }

foreach ($t in @("git", "uv", "ffmpeg")) {
    $path = Find-Command "$t.exe"
    if ($path) { "TOOL $t $path" }
}
$node = Find-Command "node.exe"
if ($node) { "TOOL node $node " + (& $node --version 2>$null | Out-String).Trim() }

$cache = Join-Path $env:LOCALAPPDATA "open-montage"
if (Test-Path -LiteralPath $cache) {
    foreach ($f in Get-ChildItem -LiteralPath $cache -Filter "keys.*" -File -ErrorAction SilentlyContinue) {
        if ($f.FullName -ne $Keep) { "STALE_STAGING $($f.FullName)" }
    }
}
exit 0
