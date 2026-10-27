# Validate one API key against its service without printing it. The key stays inside this process.
# Usage: check_key.ps1 VAR FILE   (FILE holds KEY=value lines: the staging file or .env)
# Output: "VAR: OK | INVALID | NOT_ACCEPTED | NO_PERMISSION | UNREACHABLE | MISSING | UNEXPECTED_HTTP_<code>"
# Exit code 0 only for OK.
param(
    [Parameter(Mandatory = $true, Position = 0)][string]$Var,
    [Parameter(Mandatory = $true, Position = 1)][string]$File
)

. "$PSScriptRoot\common.ps1"

$value = Get-KeyValue $File $Var
if (-not $value) { "${Var}: MISSING"; exit 1 }

Add-Type -AssemblyName System.Net.Http
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
$handler = New-Object Net.Http.HttpClientHandler
$handler.AllowAutoRedirect = $false
$client = New-Object Net.Http.HttpClient($handler)
$client.Timeout = [TimeSpan]::FromSeconds(20)
$script:body = ""

# Returns the HTTP status (0 when the service could not be reached); the body goes to $script:body.
function Send([string]$Method, [string]$Url, [hashtable]$Headers) {
    $req = New-Object Net.Http.HttpRequestMessage((New-Object Net.Http.HttpMethod($Method)), $Url)
    foreach ($k in $Headers.Keys) { [void]$req.Headers.TryAddWithoutValidation($k, $Headers[$k]) }
    try {
        $resp = $client.SendAsync($req).GetAwaiter().GetResult()
        $script:body = $resp.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        return [int]$resp.StatusCode
    } catch {
        $script:body = ""
        return 0
    }
}

function Classify([int]$Code) {
    if ($Code -eq 200) { return "OK" }
    if ($Code -eq 0 -or ($Code -ge 500 -and $Code -le 599)) { return "UNREACHABLE" }
    if ($Code -eq 400 -or $Code -eq 401 -or $Code -eq 403) { return "INVALID" }
    return "UNEXPECTED_HTTP_$Code"
}

switch ($Var) {
    "HF_TOKEN" {
        $auth = @{ Authorization = "Bearer $value" }
        $result = Classify (Send "GET" "https://huggingface.co/api/whoami-v2" $auth)
        if ($result -eq "OK") {
            # Redirects are not followed: an accepted gated model answers 200 or a 3xx to its CDN.
            $gated = Send "HEAD" "https://huggingface.co/pyannote/speaker-diarization-community-1/resolve/main/config.yaml" $auth
            if ($gated -ge 200 -and $gated -le 399) { $result = "OK" }
            elseif ($gated -eq 401 -or $gated -eq 403) { $result = "NOT_ACCEPTED" }
            else { $result = Classify $gated }
        }
    }
    "PIXABAY_API_KEY" {
        $result = Classify (Send "GET" "https://pixabay.com/api/?key=$([Uri]::EscapeDataString($value))&q=test&per_page=3" @{})
    }
    "ELEVENLABS_API_KEY" {
        $code = Send "GET" "https://api.elevenlabs.io/v1/user" @{ "xi-api-key" = $value }
        if ($code -eq 401 -and $script:body -match "missing_permissions") { $result = "NO_PERMISSION" }
        else { $result = Classify $code }
    }
    default {
        "${Var}: UNKNOWN_VAR"; exit 1
    }
}

"${Var}: $result"
if ($result -eq "OK") { exit 0 } else { exit 1 }
