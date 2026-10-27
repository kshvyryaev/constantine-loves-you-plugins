# Check an OpenMontage install end to end. Never prints key values.
# Usage: verify.ps1 INSTALL_DIR
# Output: one "PASS|WARN|FAIL|INFO <check> <detail>" line per check, then a totals line.
# INFO marks an optional local extra that is absent; it is not counted. Every slow probe has a time limit.
# Exit code 1 if any FAIL.
param([Parameter(Mandatory = $true, Position = 0)][string]$InstallDir)

. "$PSScriptRoot\common.ps1"
Update-Path
$dir = Expand-UserPath $InstallDir
$py = Join-Path $dir ".venv\Scripts\python.exe"
$envFile = Join-Path $dir ".env"
$arch = Get-NativeArch
$script:fails = 0; $script:warns = 0

function Line([string]$Status, [string]$Check, [string]$Detail) {
    "$Status $Check $Detail"
    if ($Status -eq "FAIL") { $script:fails++ }
    if ($Status -eq "WARN") { $script:warns++ }
}

function Tool([string]$Name, [string]$Arguments) {
    $exe = Find-Command "$Name.exe"
    if (-not $exe) { Line FAIL $Name "not found"; return }
    $r = Invoke-Bounded 30 $exe $Arguments
    $first = (($r.Out + "`n" + $r.Err) -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -First 1)
    if ($r.Code -eq 0 -and $first) { Line PASS $Name $first.Trim() } else { Line FAIL $Name "not working ($($r.Err.Trim()))" }
}

$build = [Environment]::OSVersion.Version.Build
if ($build -ge 17763) { Line PASS windows "build $build $arch" } else { Line FAIL windows "build $build (need Windows 10 1809+)" }
Tool git "--version"
Tool uv "--version"
Tool ffmpeg "-version"

$major = Get-NodeMajor
$nodeV = ""
if ($major -gt 0) { $nodeV = (& (Find-Command "node.exe") --version | Out-String).Trim() }
if ($major -ge 22) { Line PASS node $nodeV }
elseif ($major -gt 0) { Line FAIL node "$nodeV (need v22+)" }
else { Line FAIL node "not found" }

if (Test-VCRedist $arch) { Line PASS vcredist "Visual C++ runtime ($arch)" } else { Line FAIL vcredist "Visual C++ runtime ($arch) missing" }

if (Test-Path -LiteralPath (Join-Path $dir ".git")) {
    $head = (& git -C $dir log -1 "--format=%h %cd" --date=short 2>&1 | Out-String).Trim()
    Line PASS openmontage $head
} else {
    Line FAIL openmontage "no git clone at $dir"
}

$pyOk = $false
if (Test-Path -LiteralPath $py) {
    $pyV = (& $py --version 2>&1 | Out-String).Trim()
    if ($pyV -match '^Python 3\.1[0-3]\.') { Line PASS python "$pyV (.venv)"; $pyOk = $true } else { Line FAIL python "$pyV (.venv needs 3.10-3.13)" }
} else {
    Line FAIL python "no .venv in $dir"
}

foreach ($mod in @("faster_whisper", "whisperx", "piper", "fastapi")) {
    $r = $null
    if ($pyOk) { $r = Invoke-Bounded 120 $py "-c `"import $mod`"" $dir }
    if ($r -and $r.Code -eq 0) { Line PASS import $mod } else { Line FAIL import $mod }
}

$av = $null
if ($pyOk) { $av = Invoke-Bounded 60 $py "-c `"import av; print(av.__version__)`"" $dir }
if ($av -and $av.Code -eq 0 -and $av.Out.Trim() -match '^(\d+)\.') {
    if ([int]$Matches[1] -lt 19) { Line PASS av $av.Out.Trim() } else { Line FAIL av "$($av.Out.Trim()) (need <19: pip install `"av<19`")" }
} else {
    Line FAIL av "not importable"
}

if (Test-Path -LiteralPath (Join-Path $dir "remotion-composer\node_modules")) { Line PASS remotion "node_modules installed" } else { Line FAIL remotion "run npm install in remotion-composer" }

$npx = Find-Command "npx.cmd"
$hf = $null
if ($npx) { $hf = Invoke-Bounded 60 "cmd.exe" "/d /c `"`"$npx`" --yes hyperframes --version`"" $dir }
if ($hf -and $hf.Code -eq 0 -and $hf.Out -match '(\d+(\.\d+)+)') { Line PASS hyperframes $Matches[1] } else { Line WARN hyperframes "not available within 60 s; fetched on first render" }

if (Test-Path -LiteralPath $envFile) {
    if (Test-PrivateAcl $envFile) { Line PASS "env permissions" "current user only" } else { Line FAIL "env permissions" "other accounts can read .env" }
    foreach ($var in @("HF_TOKEN", "PIXABAY_API_KEY", "ELEVENLABS_API_KEY")) {
        if (-not (Get-KeyValue $envFile $var)) { Line WARN env "$var not set"; continue }
        $res = (& "$PSScriptRoot\check_key.ps1" $var $envFile | Out-String).Trim()
        if ($res -like "*: OK") { Line PASS key $res }
        elseif ($res -like "*: UNREACHABLE") { Line WARN key $res }
        else { Line FAIL key $res }
    }
} else {
    Line FAIL env "no .env in $dir"
}

$diar = ""
if ($pyOk) {
    $r = Invoke-Bounded 180 $py "`"$PSScriptRoot\install_compat.py`" --check" $dir
    $diar = ($r.Out -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -Last 1)
}
if ($diar -like "OK:*") { Line PASS diarization $diar.Substring(4) }
elseif ($diar) { Line WARN diarization $diar }
else { Line WARN diarization "compat check did not run" }

# Same probe as OpenMontage's `make preflight` target, without make.
$pre = $null
if ($pyOk) { $pre = Invoke-Bounded 180 $py "-c `"from tools.tool_registry import registry; import json; registry.discover(); print(json.dumps(registry.provider_menu(), indent=2))`"" $dir }
if ($pre -and $pre.Code -eq 0) { Line PASS preflight "provider registry ok" } else { Line FAIL preflight "OpenMontage provider registry failed or took over 180 s" }

# Optional local extras for HyperFrames (SKILL.md Step 10): absent is INFO, a broken setting is WARN, never FAIL.
$wp = ""
if (Test-Path -LiteralPath $envFile) { $wp = Get-KeyValue $envFile "HYPERFRAMES_WHISPER_PATH" -KeepSpaces }
$wcli = Find-Command "whisper-cli.exe"
if ($wp -and (Test-Path -LiteralPath $wp -PathType Leaf)) { Line PASS whisper-cpp $wp }
elseif ($wp) { Line WARN whisper-cpp "HYPERFRAMES_WHISPER_PATH points to a missing file: $wp" }
elseif ($wcli) { Line PASS whisper-cpp $wcli }
else { Line INFO whisper-cpp "not installed (optional local extra)" }

$missing = @("kokoro_onnx", "soundfile", "transformers", "torch", "numpy")
$extrasRan = $false
if ($pyOk) {
    $r = Invoke-Bounded 60 $py "-c `"import importlib.util as u; print('MISSING', *[m for m in ('kokoro_onnx', 'soundfile', 'transformers', 'torch', 'numpy') if u.find_spec(m) is None])`"" $dir
    $last = ($r.Out -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -Last 1)
    if ($last -like "MISSING*") { $missing = @($last.Trim() -split '\s+' | Select-Object -Skip 1); $extrasRan = $true }
}
if (-not $extrasRan) {
    Line INFO extras "Python extras check did not run"
} else {
    if ($missing -notcontains "kokoro_onnx" -and $missing -notcontains "soundfile") { Line PASS kokoro "kokoro-onnx, soundfile in .venv" } else { Line INFO kokoro "kokoro-onnx or soundfile not in .venv (optional local extra)" }
    $mg = @("transformers", "torch", "numpy", "soundfile") | Where-Object { $missing -contains $_ }
    if (-not $mg) { Line PASS musicgen "transformers, torch, numpy, soundfile in .venv" } else { Line INFO musicgen "missing in .venv: $($mg -join ' ') (optional local extra)" }
}

if (Test-Path -LiteralPath $envFile) {
    $hp = Get-KeyValue $envFile "HYPERFRAMES_PYTHON" -KeepSpaces
    if (-not $hp) {
        if ($extrasRan -and $missing -notcontains "kokoro_onnx") {
            Line WARN hyperframes-python "HYPERFRAMES_PYTHON not set in .env: HyperFrames uses the first python on PATH and misses Kokoro/MusicGen in .venv"
        } else {
            Line INFO hyperframes-python "HYPERFRAMES_PYTHON not set (needed only with local extras)"
        }
    } elseif (-not (Test-Path -LiteralPath $hp -PathType Leaf)) {
        Line WARN hyperframes-python "HYPERFRAMES_PYTHON points to a missing interpreter: $hp"
    } elseif ([IO.Path]::GetFullPath($hp) -ne [IO.Path]::GetFullPath($py)) {
        Line WARN hyperframes-python "HYPERFRAMES_PYTHON is $hp, not $py"
    } else {
        Line PASS hyperframes-python $hp
    }
}

$docker = (& "$PSScriptRoot\docker_probe.ps1" | Out-String).Trim()
switch ($docker) {
    "DOCKER RUNNING" { Line PASS docker "running" }
    "DOCKER NOT_INSTALLED" { Line INFO docker "Docker Desktop not installed (optional: isolated rendering)" }
    default { Line INFO docker "not running or no answer within 20 s (optional: isolated rendering)" }
}

"TOTAL fail=$($script:fails) warn=$($script:warns)"
if ($script:fails -eq 0) { exit 0 } else { exit 1 }
