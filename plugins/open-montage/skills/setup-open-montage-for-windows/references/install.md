# Install commands

Written for OpenMontage `main` at commit `e01dbf4` (2026-10-24), WhisperX 3.8.6, faster-whisper 1.2.1 with PyAV (`av`) below 19, uv 0.10 and HyperFrames on Node.js 22+ — the versions verified by the macOS skill (Windows verification status: SKILL.md intro). PyAV must stay below 19: av 19 removed an argument faster-whisper still passes, and faster-whisper does not cap it, so the Python brief pins `av<19`. The skill installs the latest upstream versions on purpose; if that breaks, apply § Version pin fallback. OpenMontage's README and `Makefile` are the source of truth; Windows has no `make`, so the scripts run the Makefile's Python one-liners directly.

Write literal absolute paths in place of `<INSTALL_DIR>` and `<SKILL_DIR>`. Shell, PATH and timeout rules: SKILL.md § Critical rules. Every inline command below starts with the PATH line from those rules.

Contents: [Toolchain](#toolchain) · [OpenMontage](#openmontage) · [Sub-agent briefs](#sub-agent-briefs) · [Version pin fallback](#version-pin-fallback)

## Toolchain

`install_tools.ps1` installs whatever is missing, one winget package at a time (winget runs one install at a time, so never split this across sub-agents):

| Tool | winget id | Why |
|---|---|---|
| Git | `Git.Git` | Clone and update OpenMontage |
| uv | `astral-sh.uv` | Downloads Python 3.12 and creates the venv; no system Python needed |
| FFmpeg | `Gyan.FFmpeg` | Audio and video processing |
| Node.js LTS | `OpenJS.NodeJS.LTS` | Remotion and HyperFrames (v22+ required) |
| Visual C++ runtime | `Microsoft.VCRedist.2015+.x64` (`.arm64` on ARM) | PyTorch and whisper.cpp DLLs fail to load without it |

1. **winget.** If `preflight.ps1` printed `WINGET no`, the user installs **App Installer** from the Microsoft Store (https://apps.microsoft.com/detail/9NBLGGH4NNS1), then you re-run the preflight.
2. **Warn about UAC.** Before installing, tell the user: Windows will ask "Do you want to allow this app to make changes to your device?" for Git, Node.js and the Visual C++ runtime; the prompt may blink in the taskbar instead of popping up; click **Yes**.
3. **Install** (tool timeout 30 minutes, or run it in the background):
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File "<SKILL_DIR>\scripts\install_tools.ps1"
   ```
   `PRESENT` and `INSTALLED` lines are done. `FAILED <tool> winget exit <code>` with `LOG` lines: `troubleshooting.md` § Toolchain. `OLD node <version>`: also § Toolchain — the script never replaces a Node.js it did not install. `NO_WINGET`: item 1.
4. **Python.** No system install needed: `uv` downloads Python into its own cache in the next section. The version rule lives in § OpenMontage, **Python version rule**.

## OpenMontage

Fresh install:

```powershell
$env:Path=[Environment]::GetEnvironmentVariable("Path","Machine")+";"+[Environment]::GetEnvironmentVariable("Path","User"); git clone https://github.com/calesthio/OpenMontage "<INSTALL_DIR>"; "EXIT $LASTEXITCODE"
```

Continue only on `EXIT 0`; otherwise apply `troubleshooting.md` § Dependencies, `git clone` row.

Existing clone (reinstall or update). First look for local changes:

```powershell
$env:Path=[Environment]::GetEnvironmentVariable("Path","Machine")+";"+[Environment]::GetEnvironmentVariable("Path","User"); git -C "<INSTALL_DIR>" status --short
```

- **No output** → update:
  ```powershell
  $env:Path=[Environment]::GetEnvironmentVariable("Path","Machine")+";"+[Environment]::GetEnvironmentVariable("Path","User"); git -C "<INSTALL_DIR>" pull --ff-only; "EXIT $LASTEXITCODE"
  ```
- **Any output** → show it to the user and ask before touching anything. If they agree, set the changes aside (reversible: `git stash pop` brings them back), then run the **No output** command:
  ```powershell
  $env:Path=[Environment]::GetEnvironmentVariable("Path","Machine")+";"+[Environment]::GetEnvironmentVariable("Path","User"); git -C "<INSTALL_DIR>" stash push -m "before OpenMontage setup"; "EXIT $LASTEXITCODE"
  ```
  If they decline, skip the update, keep the clone as it is, continue with the Python version rule below and list "OpenMontage not updated: local edits kept" under Open issues in the report.

Every command here must end with `EXIT 0`. A pull that still refuses on a clean clone has local commits: `troubleshooting.md` § Dependencies, `Not possible to fast-forward` row. Any other non-zero `EXIT`: the `git clone` row there.

**Python version rule.** The venv must run Python 3.10–3.13: WhisperX supports exactly that range and torch has no wheels beyond it. New venvs use 3.12. Create one only if none exists (uv refuses to overwrite an existing `.venv`):

```powershell
Set-Location "<INSTALL_DIR>"; $env:Path=[Environment]::GetEnvironmentVariable("Path","Machine")+";"+[Environment]::GetEnvironmentVariable("Path","User"); if (-not (Test-Path ".venv\Scripts\python.exe")) { uv venv --seed --python 3.12 .venv; "EXIT $LASTEXITCODE" }; .\.venv\Scripts\python.exe --version
```

`--seed` puts `pip` into the venv; the briefs call `python -m pip`.

Check: the version printed is 3.10–3.13. An `EXIT` other than 0, or `.venv\Scripts\python.exe` not found, means uv could not create the venv: `troubleshooting.md` § Dependencies, `uv venv` row — not the recreate path below. If an existing `.venv` reports anything else, ask the user, then recreate it — `--clear` deletes the old environment. If they decline, follow SKILL.md § Step 7 **Clone**:

```powershell
Set-Location "<INSTALL_DIR>"; $env:Path=[Environment]::GetEnvironmentVariable("Path","Machine")+";"+[Environment]::GetEnvironmentVariable("Path","User"); uv venv --clear --seed --python 3.12 .venv
```

## Sub-agent briefs

Launch both at once, each as its own sub-agent, with `<INSTALL_DIR>` replaced by the literal path.

### Brief: Python stack

```text
Install OpenMontage's Python dependencies into an existing virtual environment on Windows.

Folder: <INSTALL_DIR>  (an OpenMontage git clone; .venv already exists with Python 3.10–3.13)
Commands are Windows PowerShell 5.1 syntax (no && or ||). If your shell tool is Bash, wrap each one as
  powershell -NoProfile -ExecutionPolicy Bypass -Command '<command>'
Every shell call starts fresh: begin EVERY command with
  Set-Location "<INSTALL_DIR>"; $env:Path=[Environment]::GetEnvironmentVariable("Path","Machine")+";"+[Environment]::GetEnvironmentVariable("Path","User"); $env:PYTHONUTF8="1";
and end it with
  ; "EXIT $LASTEXITCODE"
A step failed when it prints EXIT with a non-zero code.
Each install can take several minutes: use a timeout of at least 10 minutes per command.

Run in order. Stop at the first failure in steps 1–5 or 7; step 6 never stops the run:
1. .\.venv\Scripts\python.exe -m pip install -r requirements.txt
2. .\.venv\Scripts\python.exe -m pip install piper-tts
3. .\.venv\Scripts\python.exe -m pip install faster-whisper
4. .\.venv\Scripts\python.exe -m pip install whisperx
5. .\.venv\Scripts\python.exe -m pip install "av<19"
6. .\.venv\Scripts\python.exe -m pip check
7. .\.venv\Scripts\python.exe -c "import faster_whisper, whisperx, piper, fastapi"

Rules:
- Do not touch .env, do not read or print any API keys, do not edit files in the repo.
- Do not install anything outside .venv and do not ask for administrator rights.
- Step 6 (pip check) may exit non-zero on harmless version conflicts: always continue to step 7 and put its output in NOTES.
- A "WinError 32 ... being used by another process" error is usually antivirus scanning new files: re-run the same step once before reporting a failure.

Return exactly:
STATUS: OK | FAILED
FAILED_COMMAND: <command or "none">
NOTES: <pip check warnings or "none">
LAST_ERROR_LINES: <last 20 lines of output on failure, otherwise "none">
```

### Brief: Node stack

```text
Install OpenMontage's Node.js dependencies on Windows.

Folder: <INSTALL_DIR>  (an OpenMontage git clone; Node.js 22+ is installed)
Commands are Windows PowerShell 5.1 syntax (no && or ||). If your shell tool is Bash, wrap each one as
  powershell -NoProfile -ExecutionPolicy Bypass -Command '<command>'
Every shell call starts fresh: begin EVERY command with
  Set-Location "<INSTALL_DIR>"; $env:Path=[Environment]::GetEnvironmentVariable("Path","Machine")+";"+[Environment]::GetEnvironmentVariable("Path","User");
and end it with
  ; "EXIT $LASTEXITCODE"
Always call npm.cmd and npx.cmd, never npm or npx: the .ps1 shims may be blocked by the execution policy.
Use a timeout of at least 10 minutes per command.

Run in order:
1. Set-Location remotion-composer; npm.cmd install
   (if it fails with ERR_INVALID_ARG_TYPE, run `Set-Location remotion-composer; npx.cmd --yes npm install`
   instead, as OpenMontage's README advises; on any other failure, stop and return STATUS: FAILED)
2. npx.cmd --yes hyperframes --version   (on failure, keep STATUS: OK and describe it in NOTES:
   HyperFrames is fetched again on first render)
3. git status --short   (npm install may rewrite a tracked lockfile; list any changed file in
   NOTES, because a dirty clone blocks the next `git pull --ff-only`)

Rules:
- Do not touch .env, do not read or print any API keys, do not edit files in the repo.
- Do not ask for administrator rights and do not install global npm packages.

Return exactly:
STATUS: OK | FAILED
FAILED_COMMAND: <command or "none">
HYPERFRAMES_VERSION: <version printed by step 2 or "none">
NOTES: <step 1 fallback if used, step 2 failure in one line and step 3 changed files, or "none">
LAST_ERROR_LINES: <last 20 lines of output on failure, otherwise "none">
```

## Version pin fallback

Use only when a brief keeps failing on a newer upstream after the fixes in `troubleshooting.md` § Dependencies. The pin moves the clone's `main` branch, so first show the user what it would drop and wait for their consent:

```powershell
$env:Path=[Environment]::GetEnvironmentVariable("Path","Machine")+";"+[Environment]::GetEnvironmentVariable("Path","User"); git -C "<INSTALL_DIR>" status --short; git -C "<INSTALL_DIR>" log --oneline origin/main..main
```

Both print nothing on an untouched clone. If they print anything and the user declines, do not pin: list the failing brief under Open issues instead. Otherwise pin OpenMontage and WhisperX to the versions from the intro:

```powershell
Set-Location "<INSTALL_DIR>"; $env:Path=[Environment]::GetEnvironmentVariable("Path","Machine")+";"+[Environment]::GetEnvironmentVariable("Path","User"); git checkout -B main e01dbf4; .\.venv\Scripts\python.exe -m pip install whisperx==3.8.6; "EXIT $LASTEXITCODE"
```

`-B main` keeps the clone on its branch, so a later `git pull --ff-only` still updates it. Re-run the failed brief, tell the user which versions are pinned and list the pin under Open issues in the report.
