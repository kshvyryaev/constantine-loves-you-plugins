# Capture one API key into the private KEY=value staging file without printing it.
# Usage:
#   ask_secret.ps1 -Var VAR -Staging FILE -Prompt "Dialog prompt"
#   ask_secret.ps1 -Var VAR -Staging FILE -FromFile PATH
#   ask_secret.ps1 -Var VAR -Staging FILE -Unset          (drop VAR, e.g. when the user skips the service)
# PATH holds either a "VAR=value" line (e.g. an existing .env; "export", quotes and " # comments" are
# handled) or the bare key on a single line.
# Output: "SAVED: VAR (N chars)" | "UNSET: VAR" | "CANCELLED: ..." (exit 3) | "ERROR: ..." (exit 2).
param(
    [Parameter(Mandatory = $true)][string]$Var,
    [Parameter(Mandatory = $true)][string]$Staging,
    [string]$Prompt,
    [string]$FromFile,
    [switch]$Unset
)

. "$PSScriptRoot\common.ps1"

function Save-Staging([string]$Value) {
    $lines = @()
    if (Test-Path -LiteralPath $Staging) {
        $lines = @([IO.File]::ReadAllLines($Staging) | Where-Object { $_ -and -not $_.StartsWith("$Var=") })
    }
    if ($Value) { $lines += "$Var=$Value" }
    Write-Utf8Lines $Staging $lines
    if (-not (Protect-Path $Staging)) { "ERROR: could not restrict $Staging to the current user"; exit 2 }
}

if ($Unset) {
    Save-Staging ""
    "UNSET: $Var"
    exit 0
}

if ($FromFile) {
    $src = Expand-UserPath $FromFile
    if (-not (Test-Path -LiteralPath $src -PathType Leaf) -or (Get-Item -LiteralPath $src).Length -eq 0) {
        "ERROR: file not found or empty: $src"; exit 2
    }
    $nonEmpty = @([IO.File]::ReadAllLines($src) | Where-Object { $_.Trim() })
    $linePattern = '^\s*(export\s+)?' + [regex]::Escape($Var) + '='
    if ($nonEmpty | Where-Object { $_ -match $linePattern }) {
        $value = Get-KeyValue $src $Var
        if (-not $value) { "ERROR: ${Var}= line is empty in $src"; exit 2 }
    } elseif ($nonEmpty.Count -eq 1 -and $nonEmpty[0] -match '^\s*(export\s+)?[A-Z_][A-Z0-9_]*=') {
        "ERROR: $src holds a different VAR= line, not $Var"; exit 2
    } elseif ($nonEmpty.Count -eq 1) {
        $value = ConvertFrom-EnvValue $nonEmpty[0]
    } else {
        "ERROR: $src has several lines and no ${Var}= line"; exit 2
    }
} else {
    if (-not $Prompt) { $Prompt = "Paste $Var" }
    try {
        Add-Type -AssemblyName System.Windows.Forms, System.Drawing
        $form = New-Object Windows.Forms.Form
        $form.Text = "OpenMontage setup"
        $form.ClientSize = New-Object Drawing.Size(440, 120)
        $form.StartPosition = "CenterScreen"
        $form.FormBorderStyle = "FixedDialog"
        $form.MaximizeBox = $false
        $form.MinimizeBox = $false
        $form.TopMost = $true
        $label = New-Object Windows.Forms.Label
        $label.Text = $Prompt
        $label.SetBounds(12, 12, 416, 20)
        $box = New-Object Windows.Forms.TextBox
        $box.UseSystemPasswordChar = $true
        $box.SetBounds(12, 38, 416, 24)
        $ok = New-Object Windows.Forms.Button
        $ok.Text = "OK"
        $ok.DialogResult = [Windows.Forms.DialogResult]::OK
        $ok.SetBounds(256, 80, 80, 28)
        $cancel = New-Object Windows.Forms.Button
        $cancel.Text = "Cancel"
        $cancel.DialogResult = [Windows.Forms.DialogResult]::Cancel
        $cancel.SetBounds(348, 80, 80, 28)
        $form.Controls.AddRange(@($label, $box, $ok, $cancel))
        $form.AcceptButton = $ok
        $form.CancelButton = $cancel
        $timer = New-Object Windows.Forms.Timer
        $timer.Interval = 600000
        $timer.Add_Tick({ $form.DialogResult = [Windows.Forms.DialogResult]::Abort; $form.Close() })
        $form.Add_Shown({ $form.Activate(); $box.Focus(); $timer.Start() })
        $result = $form.ShowDialog()
        $timer.Stop()
        $value = ConvertFrom-EnvValue $box.Text
        $form.Dispose()
    } catch {
        "ERROR: key dialog unavailable"; exit 2
    }
    if ($result -ne [Windows.Forms.DialogResult]::OK) { "CANCELLED: dialog closed for $Var"; exit 3 }
}

if (-not $value) { "CANCELLED: no value entered for $Var"; exit 3 }

Save-Staging $value
"SAVED: $Var ($($value.Length) chars)"
