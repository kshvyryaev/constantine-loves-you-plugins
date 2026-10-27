# Download the prebuilt whisper.cpp CLI for Windows into %LOCALAPPDATA%\open-montage\whisper.cpp.
# whisper.cpp attaches Windows binaries to its build releases (bNNNN), not to the vX.Y.Z tags, so the
# newest release that carries the asset for this CPU is used. Nothing is added to PATH: HyperFrames
# finds the binary through HYPERFRAMES_WHISPER_PATH, which SKILL.md Step 10 writes into .env.
# Usage: install_whisper.ps1
# Output: "WHISPER_CLI <path>" and "RELEASE <tag>" | "ERROR: ..." (exit 1).

. "$PSScriptRoot\common.ps1"

$asset = "whisper-bin-x64.zip"
if ((Get-NativeArch) -eq "arm64") { $asset = "whisper-bin-win-cpu-arm64.zip" }
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

try {
    $releases = Invoke-RestMethod -Uri "https://api.github.com/repos/ggml-org/whisper.cpp/releases?per_page=15" -Headers @{ "User-Agent" = "open-montage-setup" } -TimeoutSec 30
} catch {
    "ERROR: GitHub releases not reachable ($($_.Exception.Message))"; exit 1
}
$release = $releases | Where-Object { $_.assets.name -contains $asset } | Select-Object -First 1
if (-not $release) { "ERROR: no recent whisper.cpp release carries $asset"; exit 1 }
$url = ($release.assets | Where-Object { $_.name -eq $asset } | Select-Object -First 1).browser_download_url

$root = Join-Path $env:LOCALAPPDATA "open-montage\whisper.cpp"
$dest = Join-Path $root $release.tag_name
$cli = Get-ChildItem -LiteralPath $dest -Recurse -Filter "whisper-cli.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $cli) {
    New-Item -ItemType Directory -Force -Path $root | Out-Null
    $zip = Join-Path $root "$($release.tag_name).zip"
    try {
        Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing -TimeoutSec 600
        Expand-Archive -LiteralPath $zip -DestinationPath $dest -Force
    } catch {
        Remove-Item -LiteralPath $dest -Recurse -Force -ErrorAction SilentlyContinue
        "ERROR: download or unpack failed ($($_.Exception.Message))"; exit 1
    } finally {
        Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
    }
    $cli = Get-ChildItem -LiteralPath $dest -Recurse -Filter "whisper-cli.exe" | Select-Object -First 1
}
if (-not $cli) { "ERROR: whisper-cli.exe not found in $asset"; exit 1 }

$r = Invoke-Bounded 30 $cli.FullName "--help"
if ($r.Code -ne 0) { "ERROR: whisper-cli.exe does not start (exit $($r.Code)); the Visual C++ runtime may be missing"; exit 1 }
"WHISPER_CLI $($cli.FullName)"
"RELEASE $($release.tag_name)"
