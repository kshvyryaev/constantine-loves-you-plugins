# Shared helpers, dot-sourced by the other scripts. Windows PowerShell 5.1 compatible.

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

# Reload PATH from the registry: tools installed by winget during this session are not on the
# PATH this shell inherited from the client.
function Update-Path {
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
}

function Expand-UserPath([string]$Path) {
    $p = [Environment]::ExpandEnvironmentVariables($Path.Trim().Trim('"'))
    if ($p -eq "~") { $p = $HOME }
    elseif ($p.StartsWith("~\") -or $p.StartsWith("~/")) { $p = Join-Path $HOME $p.Substring(2) }
    return [IO.Path]::GetFullPath($p)
}

# Strip an inline " # comment", surrounding quotes and (unless -KeepSpaces) all whitespace.
function ConvertFrom-EnvValue([string]$Value, [switch]$KeepSpaces) {
    # A quoted value is taken verbatim up to its closing quote, as OpenMontage's own loader does.
    $t = $Value.Trim()
    if ($t.Length -gt 0 -and ($t[0] -eq '"' -or $t[0] -eq "'")) {
        $end = $t.IndexOf($t[0], 1)
        if ($end -lt 0) { return $t.Substring(1) }
        return $t.Substring(1, $end - 1)
    }
    $v = $Value -replace '(^|\s)#.*$', ''
    if ($KeepSpaces) { $v = $v.Trim() } else { $v = $v -replace '\s', '' }
    if ($v.StartsWith('"')) { $v = $v.Substring(1) }
    if ($v.EndsWith('"')) { $v = $v.Substring(0, $v.Length - 1) }
    if ($v.StartsWith("'")) { $v = $v.Substring(1) }
    if ($v.EndsWith("'")) { $v = $v.Substring(0, $v.Length - 1) }
    return $v
}

# Value of VAR from a KEY=value file (staging file or .env); "" when absent.
function Get-KeyValue([string]$Path, [string]$Var, [switch]$KeepSpaces) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return "" }
    $pattern = '^\s*(export\s+)?' + [regex]::Escape($Var) + '=(.*)$'
    foreach ($line in [IO.File]::ReadAllLines($Path)) {
        if ($line -match $pattern) { return (ConvertFrom-EnvValue $Matches[2] -KeepSpaces:$KeepSpaces) }
    }
    return ""
}

function Write-Utf8Lines([string]$Path, [string[]]$Lines) {
    $text = ""
    if ($Lines.Count -gt 0) { $text = ($Lines -join "`n") + "`n" }
    [IO.File]::WriteAllText($Path, $text, (New-Object Text.UTF8Encoding($false)))
}

function Get-CurrentSid {
    return [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
}

# Remove inherited and explicit access, then grant only the current user full control.
function Protect-Path([string]$Path) {
    $sid = Get-CurrentSid
    $grant = "*${sid}:F"
    if (Test-Path -LiteralPath $Path -PathType Container) { $grant = "*${sid}:(OI)(CI)F" }
    & icacls.exe $Path /reset 2>&1 | Out-Null
    & icacls.exe $Path /inheritance:r /grant:r $grant 2>&1 | Out-Null
    return ($LASTEXITCODE -eq 0)
}

# True when only the current user has access and inheritance is off.
function Test-PrivateAcl([string]$Path) {
    $acl = Get-Acl -LiteralPath $Path
    if (-not $acl.AreAccessRulesProtected) { return $false }
    $me = Get-CurrentSid
    foreach ($rule in $acl.Access) {
        try { $sid = $rule.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value } catch { return $false }
        if ($sid -ne $me) { return $false }
    }
    return $true
}

function Get-NativeArch {
    $a = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment").PROCESSOR_ARCHITECTURE
    switch ($a) { "AMD64" { return "x64" } "ARM64" { return "arm64" } default { return $a } }
}

function Test-VCRedist([string]$Arch) {
    foreach ($root in @("HKLM:\SOFTWARE\Microsoft", "HKLM:\SOFTWARE\WOW6432Node\Microsoft")) {
        $key = "$root\VisualStudio\14.0\VC\Runtimes\$Arch"
        $p = Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue
        if ($p -and $p.Installed -eq 1) { return $true }
    }
    return $false
}

function Get-FreeGb([string]$Path) {
    $p = $Path
    while ($p -and -not (Test-Path -LiteralPath $p)) { $p = Split-Path $p -Parent }
    if (-not $p) { return -1 }
    try {
        $root = [IO.Path]::GetPathRoot((Resolve-Path -LiteralPath $p).ProviderPath)
        return [int][math]::Floor((New-Object IO.DriveInfo $root).AvailableFreeSpace / 1GB)
    } catch { return -1 }
}

# Run an executable with a time limit; the whole process tree is killed on timeout.
# Returns Code ($null on timeout), Out, Err.
function Invoke-Bounded([int]$Seconds, [string]$FilePath, [string]$Arguments, [string]$WorkDir) {
    $psi = New-Object Diagnostics.ProcessStartInfo
    $psi.FileName = $FilePath
    $psi.Arguments = $Arguments
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    if ($WorkDir) { $psi.WorkingDirectory = $WorkDir }
    try { $p = [Diagnostics.Process]::Start($psi) } catch {
        return [pscustomobject]@{ Code = -1; Out = ""; Err = $_.Exception.Message }
    }
    $out = $p.StandardOutput.ReadToEndAsync()
    $err = $p.StandardError.ReadToEndAsync()
    if (-not $p.WaitForExit($Seconds * 1000)) {
        & taskkill.exe /T /F /PID $p.Id 2>&1 | Out-Null
        return [pscustomobject]@{ Code = $null; Out = ""; Err = "timeout after $Seconds s" }
    }
    $p.WaitForExit()
    # A child that inherited the output pipe can keep it open after the process exits.
    if (-not $out.Wait(10000) -or -not $err.Wait(10000)) {
        & taskkill.exe /T /F /PID $p.Id 2>&1 | Out-Null
        return [pscustomobject]@{ Code = $p.ExitCode; Out = ""; Err = "output pipe still open after exit" }
    }
    return [pscustomobject]@{ Code = $p.ExitCode; Out = $out.Result; Err = $err.Result }
}

# Full path of a command after the PATH reload, or "".
function Find-Command([string]$Name) {
    $c = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($c) { return $c.Source }
    return ""
}

function Get-NodeMajor {
    $node = Find-Command "node.exe"
    if (-not $node) { return 0 }
    $v = (& $node --version 2>$null | Out-String).Trim()
    if ($v -match '^v(\d+)') { return [int]$Matches[1] }
    return 0
}
