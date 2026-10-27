# Install commands

Written for OpenMontage `main` at commit `e01dbf4` (2026-10-24), WhisperX 3.8.6, faster-whisper 1.2.1 with PyAV (`av`) below 19, uv 0.10 and HyperFrames on Node.js 22+ — the versions verified by the macOS skill (Windows verification status: SKILL.md § Verification status). PyAV must stay below 19: av 19 removed an argument faster-whisper still passes, and faster-whisper does not cap it, so `install_python_deps.ps1` pins `av<19`. The skill installs the latest upstream versions on purpose; if that breaks, apply § Version pin fallback. OpenMontage's README and `Makefile` are the source of truth; Windows has no `make`, so the scripts run the Makefile's Python one-liners directly.

Write literal absolute paths in place of `<INSTALL_DIR>` and `<SKILL_DIR>`. Shell, PATH and timeout rules: SKILL.md § Critical rules. Inline commands below start with `<PATH line>`: write out the PATH line from SKILL.md § Critical rules in its place. Scripts reload PATH themselves.

Contents: [Toolchain](#toolchain) · [OpenMontage](#openmontage) · [Dependency scripts](#dependency-scripts) · [Version pin fallback](#version-pin-fallback)

## Toolchain

`install_tools.ps1` installs whatever is missing, one winget package at a time (winget runs one install at a time, so never run two of them at once):

| Tool | winget id | Why |
|---|---|---|
| Git | `Git.Git` | Clone and update OpenMontage |
| uv | `astral-sh.uv` | Downloads Python 3.12 and creates the venv; no system Python needed |
| FFmpeg | `Gyan.FFmpeg` | Audio and video processing |
| Node.js LTS | `OpenJS.NodeJS.LTS` | Remotion and HyperFrames (v22+ required) |
| Visual C++ runtime | `Microsoft.VCRedist.2015+.x64` (`.arm64` on ARM) | PyTorch and whisper.cpp DLLs fail to load without it |

1. **winget.** If `preflight.ps1` printed `WINGET no`, the user installs **App Installer** from the Microsoft Store (https://apps.microsoft.com/detail/9NBLGGH4NNS1), then you re-run the preflight with `-Keep "<STAGING>"`, so the current key file is not listed as a leftover.
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
<PATH line> git clone https://github.com/calesthio/OpenMontage "<INSTALL_DIR>"; "EXIT $LASTEXITCODE"
```

Continue only on `EXIT 0`; otherwise apply `troubleshooting.md` § Dependencies, `git clone` row.

Existing clone (reinstall or update). First look for local changes:

```powershell
<PATH line> git -C "<INSTALL_DIR>" status --short
```

- **No output** → update:
  ```powershell
  <PATH line> git -C "<INSTALL_DIR>" pull --ff-only; "EXIT $LASTEXITCODE"
  ```
- **Any output** → show it to the user and ask before touching anything. If they agree, set the changes aside (reversible: `git stash pop` brings them back), then run the **No output** command:
  ```powershell
  <PATH line> git -C "<INSTALL_DIR>" stash push -m "before OpenMontage setup"; "EXIT $LASTEXITCODE"
  ```
  If they decline, skip the update and continue with the Python version rule below; the outcome is in SKILL.md § Step 7 **Clone**.

Every command here must end with `EXIT 0`. A pull that still refuses on a clean clone has local commits: `troubleshooting.md` § Dependencies, `Not possible to fast-forward` row. Any other non-zero `EXIT`: the `git clone` row there.

**Python version rule.** The venv must run Python 3.10–3.13: WhisperX supports exactly that range and torch has no wheels beyond it. New venvs use 3.12. Create one only if none exists (uv refuses to overwrite an existing `.venv`):

```powershell
Set-Location "<INSTALL_DIR>"; <PATH line> if (-not (Test-Path ".venv\Scripts\python.exe")) { uv venv --seed --python 3.12 .venv; "EXIT $LASTEXITCODE" }; .\.venv\Scripts\python.exe --version
```

`--seed` puts `pip` into the venv; the dependency scripts call `python -m pip`.

Check: the version printed is 3.10–3.13. An `EXIT` other than 0, or `.venv\Scripts\python.exe` not found, means uv could not create the venv: `troubleshooting.md` § Dependencies, `uv venv` row — not the recreate path below. If an existing `.venv` reports anything else, ask the user, then recreate it — `--clear` deletes the old environment. If they decline, follow SKILL.md § Step 7 **Clone**:

```powershell
Set-Location "<INSTALL_DIR>"; <PATH line> uv venv --clear --seed --python 3.12 .venv
```

## Dependency scripts

Both scripts run their steps in a fixed order, stop at the first failure, and end with the same block: `STATUS: OK | FAILED`, `FAILED_COMMAND`, `NOTES`, then `LAST_ERROR_LINES`. They never read `.env` and need no administrator rights. Start both at once (SKILL.md § Step 7):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<SKILL_DIR>\scripts\install_python_deps.ps1" "<INSTALL_DIR>"
powershell -NoProfile -ExecutionPolicy Bypass -File "<SKILL_DIR>\scripts\install_node_deps.ps1" "<INSTALL_DIR>"
```

- **Python** (`install_python_deps.ps1`): into `.venv`, `pip install` of `requirements.txt`, `piper-tts`, `faster-whisper`, `whisperx` and `av<19`; then `pip check` (findings go to `NOTES`, never a failure); then an import check of `faster_whisper`, `whisperx`, `piper` and `fastapi`. A `WinError 32` file lock is retried once per step. Each install has a 60-minute limit; torch alone is a large download.
- **Node** (`install_node_deps.ps1`): `npm.cmd install` in `remotion-composer`, falling back to `npx.cmd --yes npm install` on `ERR_INVALID_ARG_TYPE` (OpenMontage README); then `npx.cmd --yes hyperframes --version`, whose failure is only a note (`HYPERFRAMES_VERSION: none`); then `git status --short`, because a rewritten lockfile blocks the next `git pull --ff-only`. It adds a `HYPERFRAMES_VERSION` line.

## Version pin fallback

Use only when a dependency script keeps failing on a newer upstream after the fixes in `troubleshooting.md` § Dependencies. The pin moves the clone's `main` branch, so first show the user what it would drop and wait for their consent:

```powershell
<PATH line> git -C "<INSTALL_DIR>" status --short; git -C "<INSTALL_DIR>" log --oneline origin/main..main
```

Both print nothing on an untouched clone. If they print anything and the user declines, do not pin (outcome: SKILL.md § Step 7 **Reports**). Otherwise pin OpenMontage and WhisperX to the versions from the intro:

```powershell
Set-Location "<INSTALL_DIR>"; <PATH line> git checkout -B main e01dbf4; .\.venv\Scripts\python.exe -m pip install whisperx==3.8.6; "EXIT $LASTEXITCODE"
```

`-B main` keeps the clone on its branch, so a later `git pull --ff-only` still updates it. Re-run the failed script, tell the user which versions are pinned and list the pin under Open issues in the report.
