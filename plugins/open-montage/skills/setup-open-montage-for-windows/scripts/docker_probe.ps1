# Check whether Docker Desktop is installed and answering, with a 20-second limit on `docker info`.
# Usage: docker_probe.ps1 [-Start]   (-Start launches Docker Desktop first and does not probe)
# Output: "DOCKER RUNNING" (exit 0) | "DOCKER NOT_RUNNING" (exit 1) | "DOCKER NOT_INSTALLED" (exit 2)
#   | "DOCKER STARTING" (with -Start).
param([switch]$Start)

. "$PSScriptRoot\common.ps1"
Update-Path

$app = Join-Path $env:ProgramFiles "Docker\Docker\Docker Desktop.exe"
$cli = Find-Command "docker.exe"
$bundled = Join-Path $env:ProgramFiles "Docker\Docker\resources\bin\docker.exe"
if (-not $cli -and (Test-Path -LiteralPath $bundled)) { $cli = $bundled }
if (-not $cli -and -not (Test-Path -LiteralPath $app)) { "DOCKER NOT_INSTALLED"; exit 2 }

if ($Start) {
    if (-not (Test-Path -LiteralPath $app)) { "DOCKER NOT_INSTALLED"; exit 2 }
    Start-Process -FilePath $app
    "DOCKER STARTING"
    exit 0
}

if (-not $cli) { "DOCKER NOT_RUNNING"; exit 1 }
$r = Invoke-Bounded 20 $cli "info"
if ($r.Code -eq 0) { "DOCKER RUNNING"; exit 0 }
"DOCKER NOT_RUNNING"
exit 1
