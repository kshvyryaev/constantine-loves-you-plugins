# Troubleshooting

Find the symptom, apply the fix, re-run the step's check. First-time handling of `check_key.ps1` results is in SKILL.md § Steps 2–4; § Keys covers results that persist after that handling. The PATH line and the shell rules are in SKILL.md § Critical rules.

Contents: [Shell](#shell) · [Keys](#keys) · [Toolchain](#toolchain) · [Dependencies](#dependencies) · [Local extras](#local-extras) · [Verification](#verification)

## Shell

| Symptom | Cause | Fix |
|---|---|---|
| `The token '&&' is not a valid statement separator` | Bash syntax in Windows PowerShell 5.1 | Join commands with `;` and check `$LASTEXITCODE` |
| `... cannot be loaded because running scripts is disabled on this system` | Execution policy blocks `.ps1` files, including the `npm.ps1` shim | Run scripts through `powershell -NoProfile -ExecutionPolicy Bypass -File …`; call `npm.cmd` and `npx.cmd` |
| The same error even with `-ExecutionPolicy Bypass`, or `AuthorizationManager check failed` | Group Policy on a managed PC overrides the process policy | No fix in the skill: tell the user their IT policy blocks PowerShell scripts and stop |
| `git`, `uv`, `node` or `ffmpeg` "is not recognized" right after `install_tools.ps1` printed `INSTALLED` | The command did not start with the PATH line | Prefix the command with the PATH line |
| Variables like `$env:Path` arrive empty from a Bash tool | The Bash wrap used double quotes, so Bash expanded `$…` | Wrap with single quotes: `powershell -NoProfile -ExecutionPolicy Bypass -Command '<command>'` |

## Keys

| Symptom | Cause | Fix |
|---|---|---|
| `ERROR: key dialog unavailable` | No interactive desktop (SSH, remote service, headless client) | Use `-FromFile`: the user saves the key to a text file and names the path |
| The dialog never appears and the command waits | The window opened behind other windows | Ask the user to look for "OpenMontage setup" in the taskbar; the dialog closes itself after 10 minutes (`CANCELLED`) |
| `ERROR: … has several lines and no <VAR>= line` or `… holds a different VAR= line` | The named file is not a key file for this service | Ask for a file with only the key, or one with a `<VAR>=` line |
| `ERROR: file not found or empty` | Wrong path or empty file | Ask the user for the exact path (`~` and `%USERPROFILE%` are allowed) |
| `ERROR: … VAR= line is empty` | The file has the variable but no value (e.g. a copy of `.env.example`) | Ask for the file that holds the real key, or use the dialog |
| `ERROR: could not restrict … to the current user` | `icacls` was refused, e.g. the folder is on a network or FAT drive | Staging: tell the user `%LOCALAPPDATA%` is not usable and stop. `.env`: ask for an install folder on a local NTFS drive |
| `HF_TOKEN` stays `INVALID` with a correct-looking token | Fine-grained token without read access to public repos | Create a token of type **Read** |
| `NOT_ACCEPTED` after the user accepted | Accepted with a different Hugging Face account than the token's | Accept the model terms while signed in to the token's account |
| `NOT_ACCEPTED` with the right account | Fine-grained token without access to gated repositories | Create a token of type **Read**, or enable "Read access to contents of all public gated repos" on the fine-grained token |
| Every key `UNREACHABLE` while the browser works | A corporate proxy that .NET does not pick up, or TLS inspection | Keep the keys as `unverified`; the user can re-check later on another network |

## Toolchain

| Symptom | Cause | Fix |
|---|---|---|
| `NO_WINGET` / `WINGET no` | App Installer missing (older Windows 10, LTSC, Windows Server) | The user installs App Installer from the Microsoft Store (https://apps.microsoft.com/detail/9NBLGGH4NNS1). Without the Store, they install the tool from its own site; re-run `install_tools.ps1 -CheckOnly` afterwards |
| `FAILED … winget exit 1602` or `1223`, or `LOG` lines saying the installation was cancelled | The user declined the UAC prompt, or it timed out | Ask the user to run `install_tools.ps1` again and click **Yes** |
| `FAILED … winget exit` with `LOG` lines about the `msstore` source or source agreements | winget sources not initialised | The user runs `winget source reset --force` in an administrator PowerShell, then re-run `install_tools.ps1` |
| `FAILED …` with another code | Installer or network problem | Show the user the `LOG` lines; they can install that tool from its own site (git-scm.com, docs.astral.sh/uv, gyan.dev/ffmpeg, nodejs.org, the Microsoft Visual C++ Redistributable page), then re-run `install_tools.ps1 -CheckOnly` |
| `OLD node v18…` (or any version below 22) | Another Node.js (nvm-windows, an older installer) comes first on `PATH` | Ask the user. With nvm-windows: `nvm install 22` and `nvm use 22`. Otherwise they uninstall the old Node.js in Settings → Apps, then re-run `install_tools.ps1` |

## Dependencies

| Symptom | Cause | Fix |
|---|---|---|
| `git clone` or `git pull` ends with a non-zero `EXIT` (`Could not resolve host`, `Failed to connect`, `SSL certificate problem`) | No network, a proxy, or TLS inspection on a corporate network | Re-run once. If it repeats, the user checks the network or proxy (their own `git config --global http.proxy …` is their choice); list it under Open issues and go to SKILL.md § Step 11 |
| `uv venv` ends with a non-zero `EXIT` (`Failed to download`, `error sending request`) | uv could not download Python 3.12 | Re-run once. If it repeats, treat it like the `git clone` row: network or proxy, user's choice, then Open issues |
| `No module named pip` | venv created without `--seed` | Recreate it with the `--clear` command in `install.md` § OpenMontage, **Python version rule** |
| `A virtual environment already exists at .venv` | `uv venv` run over an existing venv | Apply `install.md` § OpenMontage, **Python version rule** |
| `No matching distribution found for torch` | venv Python outside the supported range | Apply `install.md` § OpenMontage, **Python version rule** |
| `No matching distribution found for ctranslate2` (or torch) with a 3.10–3.13 venv on `ARCH arm64` | Missing Windows ARM64 wheels (SKILL.md § Step 1 **Status**) | No fix in the skill: list it under Open issues |
| `OSError: [WinError 126]` naming `fbgemm.dll`, `c10.dll` or another DLL when importing torch, whisperx or pyannote | Visual C++ runtime missing | Re-run `install_tools.ps1` (it installs `vcredist`), then re-run `install_python_deps.ps1` |
| `[WinError 206] The filename or extension is too long`, or pip `No such file or directory` deep inside `site-packages` | Windows 260-character path limit (`LONGPATHS no`) with a long install path | Use a shorter install folder such as `C:\OpenMontage`, or the user enables long paths in an administrator PowerShell: `New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name LongPathsEnabled -Value 1 -PropertyType DWORD -Force`, then re-run `install_python_deps.ps1` |
| `PermissionError: [WinError 32] … being used by another process` | Antivirus scanning freshly unpacked files | Re-run `install_python_deps.ps1` (it already retried once; finished steps are skipped by pip). If it repeats, the user may exclude the install folder from real-time scanning; that is their decision |
| `UnicodeEncodeError: 'charmap' codec can't encode` | Python writes to a non-UTF-8 console | Add `$env:PYTHONUTF8="1";` to the command, as `install_python_deps.ps1` does |
| `pip install whisperx` fails on `torchcodec` or `av` | Missing or broken FFmpeg | Re-run `install_tools.ps1 -CheckOnly`; if FFmpeg is missing, run it without `-CheckOnly`, then re-run `install_python_deps.ps1` |
| Transcription fails with `TypeError: open() got an unexpected keyword argument 'metadata_errors'` | PyAV 19+ installed; faster-whisper does not cap `av` | `.\.venv\Scripts\python.exe -m pip install "av<19"`, then `.\.venv\Scripts\python.exe -m pip check` |
| pyannote prints a long `torchcodec is not installed correctly … FFmpeg` UserWarning | The installed FFmpeg is newer than torchcodec supports | Ignore it: WhisperX decodes audio with the `ffmpeg` CLI and hands pyannote an in-memory waveform |
| Hugging Face warns that its cache uses symlinks and Windows does not support them | Developer Mode is off | Ignore it: models are copied instead of linked and use more disk space |
| `npm ERR! code ERR_INVALID_ARG_TYPE` | Known npm issue on Windows (OpenMontage README) | `install_node_deps.ps1` falls back to `npx.cmd --yes npm install` by itself; if that also fails, show the user its `LAST_ERROR_LINES` |
| `npx hyperframes` hangs or fails | Offline or npm registry blocked | Not a blocker: HyperFrames is fetched on first render |
| `git pull --ff-only` refuses and `git status --short` prints files | Local changes in the clone | Apply `install.md` § OpenMontage, **Any output** |
| `Not possible to fast-forward` with a clean `git status --short` | Local commits on `main` (the history diverged) | Show the user `git -C "<INSTALL_DIR>" log --oneline origin/main..main`. If they agree to leave those commits behind (they stay reachable through `git reflog`), run `git -C "<INSTALL_DIR>" checkout -B main origin/main`. If they decline, skip the update and list "OpenMontage not updated: local commits kept" under Open issues |
| `git pull --ff-only` says `You are not currently on a branch` | The clone was pinned with a plain `git checkout <commit>` | `git -C "<INSTALL_DIR>" switch main`, then pull again |
| A dependency script keeps failing after the fixes above, on an error none of them covers | Newer upstream OpenMontage or WhisperX broke the install | Go back to SKILL.md § Step 7 **Reports**: its last fallback is the version pin, after asking the user |
| `install_compat.py` prints `FAIL` | WhisperX changed its diarization API again | Leave it; diarization is optional. Report it so the user can check upstream OpenMontage and WhisperX issues |

## Local extras

| Symptom | Cause | Fix |
|---|---|---|
| The doctor says HyperFrames is unavailable (`runtime_available=False`, `npm … not resolvable: timeout (5s)`, "npm did not answer"), while a run minutes later is fine | OpenMontage gives `npm view hyperframes version` only 5 seconds; slow or flaky registry lookups miss it | Transient, nothing to reinstall: run `hyperframes_doctor.py` once more. If it repeats, list it under Open issues; Remotion still covers titles and captions |
| `install_whisper.ps1` prints `ERROR: GitHub releases not reachable` | Offline, proxy, or the GitHub API rate limit (60 requests per hour without sign-in) | Retry later; list "whisper.cpp not installed" under Open issues if it persists |
| `install_whisper.ps1` prints `ERROR: no recent whisper.cpp release carries …` | whisper.cpp renamed its Windows asset | List it under Open issues; the user can download a `whisper-bin-*.zip` from https://github.com/ggml-org/whisper.cpp/releases and you set `HYPERFRAMES_WHISPER_PATH` to its `whisper-cli.exe` with `write_env.py --set` |
| `install_whisper.ps1` prints `ERROR: whisper-cli.exe does not start` | Visual C++ runtime missing | Re-run `install_tools.ps1`, then `install_whisper.ps1` |
| `docker info` hangs, returns `500 Internal Server Error`, or `docker_probe.ps1` keeps printing `NOT_RUNNING` | Docker Desktop is still starting, or waits for its first-run window (terms, sign-in, survey) | Ask the user to finish or skip that window, then probe again. If it persists, the user quits and reopens Docker Desktop. The three-probe limit in SKILL.md § Step 10 applies |
| Docker Desktop reports that WSL 2 is missing or needs an update | WSL 2 not installed | The user's choice: `wsl --install` in an administrator PowerShell and a restart. Otherwise list "Docker not running (optional)" under Open issues |
| Doctor flags a newer HyperFrames (`0.8.185 → 0.8.197 available`) and nothing changes after refreshing | The doctor's notice can be ahead of npm | `Set-Location "<INSTALL_DIR>"; npm.cmd view hyperframes dist-tags --json`. If `latest` equals the installed version, it is not an issue: do not list it. If `latest` is newer, `npx.cmd --yes --prefer-online hyperframes --version` refreshes the cache |
| Doctor shows ✗ for Kokoro or MusicGen although the packages are in `.venv` | `HYPERFRAMES_PYTHON` is unset or points at another Python, so HyperFrames looks in the wrong interpreter | Run `Set-Location "<INSTALL_DIR>"; .\.venv\Scripts\python.exe "<SKILL_DIR>\scripts\write_env.py" "<INSTALL_DIR>\.env" --set "HYPERFRAMES_PYTHON=<INSTALL_DIR>\.venv\Scripts\python.exe"`, then the doctor again |
| Doctor shows ✗ for whisper-cpp after `install_whisper.ps1` succeeded | `HYPERFRAMES_WHISPER_PATH` not written, or the path moved | Run `Set-Location "<INSTALL_DIR>"; .\.venv\Scripts\python.exe "<SKILL_DIR>\scripts\write_env.py" "<INSTALL_DIR>\.env" --set "HYPERFRAMES_WHISPER_PATH=<WHISPER_CLI path>"` with the current `WHISPER_CLI` path |
| Doctor still shows the old interpreter or whisper path after fixing `.env` | The variable is also set in the user's Windows environment; OpenMontage lets the environment win over `.env` | Ask the user to remove it in Settings → System → About → Advanced system settings → Environment Variables, then open a new terminal |
| `pip install kokoro-onnx` moves `av` to 19 or newer | A dependency upgrade pulled a newer PyAV | Apply § Dependencies, `metadata_errors` row |

## Verification

| `verify.ps1` line | Fix |
|---|---|
| `FAIL windows` | Unsupported system; stop and tell the user |
| `FAIL git/uv/ffmpeg not found` or `FAIL vcredist …` | Repeat SKILL.md § Step 6 |
| `FAIL node … (need v22+)` | See § Toolchain, `OLD node` row |
| `FAIL node not found` | Repeat SKILL.md § Step 6 |
| `WARN hyperframes not available…` | Not a blocker: HyperFrames is fetched on first render. Optionally re-run `install_node_deps.ps1` |
| `FAIL openmontage no git clone at …` | Repeat SKILL.md § Step 7 **Clone** |
| `FAIL env no .env in …` | Re-run the `write_env.py` command from SKILL.md § Step 8 (with a new staging file if the old one is gone) |
| `FAIL python …` | Apply `install.md` § OpenMontage, **Python version rule**, then re-run `install_python_deps.ps1` |
| `FAIL import <module>` | Re-run `install_python_deps.ps1`; read its `LAST_ERROR_LINES`. A `WinError 126`: § Dependencies |
| `FAIL av …` | `.\.venv\Scripts\python.exe -m pip install "av<19"` (see § Dependencies, `metadata_errors` row) |
| `FAIL remotion …` | Re-run `install_node_deps.ps1` |
| `FAIL env permissions other accounts can read .env` | Re-run any `write_env.py` command from SKILL.md § Step 8: it restricts the file before writing |
| `WARN env <VAR> not set` | The service was skipped; offer SKILL.md § Add or replace a key later |
| `FAIL key <VAR>: NOT_ACCEPTED` or `NO_PERMISSION` | Same action as that result in the SKILL.md § Steps 2–4 table, then re-run `verify.ps1`; the key itself stays |
| `FAIL key <VAR>: INVALID` or `MISSING` | Offer SKILL.md § Add or replace a key later for that service |
| `FAIL key <VAR>: UNEXPECTED_HTTP_<code>` | Re-run `verify.ps1` once; if it repeats, report it as unverified with the code |
| `WARN key <VAR>: UNREACHABLE` | Network issue; not a blocker. Suggest retrying later or with a VPN |
| `WARN diarization FAIL: compatibility layer not installed …` | Run the `install_compat.py` command from SKILL.md § Step 8 |
| `WARN diarization SKIP: …` | WhisperX is not installed: re-run `install_python_deps.ps1` |
| `WARN diarization FAIL: …` (other) or `compat check did not run` | WhisperX changed again or `.venv` is broken: report it as an open issue; diarization is optional |
| `FAIL preflight` | Run `Set-Location "<INSTALL_DIR>"; .\.venv\Scripts\python.exe -c "from tools.tool_registry import registry; registry.discover()"` and show the user the last 20 lines; if the module no longer exists upstream, report it as an open issue. If it only timed out, see § Local extras, `runtime_available=False` row |
| `INFO whisper-cpp/kokoro/musicgen/docker …` or `INFO hyperframes-python … not set` | Optional local extra not set up: nothing to fix. Offer SKILL.md § Add local extras later if the user wants it |
| `WARN hyperframes-python …` (not set while Kokoro is installed, missing interpreter, or not the `.venv` Python) | Run `Set-Location "<INSTALL_DIR>"; .\.venv\Scripts\python.exe "<SKILL_DIR>\scripts\write_env.py" "<INSTALL_DIR>\.env" --set "HYPERFRAMES_PYTHON=<INSTALL_DIR>\.venv\Scripts\python.exe"`; it replaces the old line |
| `WARN whisper-cpp HYPERFRAMES_WHISPER_PATH points to a missing file` | Run `install_whisper.ps1`, then `Set-Location "<INSTALL_DIR>"; .\.venv\Scripts\python.exe "<SKILL_DIR>\scripts\write_env.py" "<INSTALL_DIR>\.env" --set "HYPERFRAMES_WHISPER_PATH=<WHISPER_CLI path>"` |
