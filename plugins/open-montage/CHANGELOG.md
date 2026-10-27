# Changelog

## 1.4.0 — 2026-10-27

### Added

- `setup-open-montage-for-windows` skill: the same guided flow for Windows 10 1809+ and Windows 11 (x64; ARM64 warned before any sign-up). **Not yet run end to end on a real Windows machine**: the skill says so and asks the agent to report every step that behaves differently.
  - Scripts are Windows PowerShell 5.1 (`preflight.ps1`, `new_staging.ps1`, `ask_secret.ps1`, `check_key.ps1`, `install_tools.ps1`, `verify.ps1`, `install_whisper.ps1`, `docker_probe.ps1`, shared `common.ps1`), run through `powershell -NoProfile -ExecutionPolicy Bypass -File`, so they work from a PowerShell or a Git Bash shell tool.
  - Keys go through a hidden Windows Forms dialog or a file; the staging file lives in `%LOCALAPPDATA%\open-montage` and, like `.env`, is restricted to the current user with `icacls` (the counterpart of mode 600).
  - Toolchain through winget: Git, uv, FFmpeg, Node.js LTS and the Visual C++ runtime (PyTorch DLLs fail without it). Every inline command reloads `PATH` from the registry, so tools installed during the session are found.
  - No `make` on Windows: `verify.ps1` and `hyperframes_doctor.py` run the Makefile's Python one-liners directly.
  - Local extras: whisper.cpp comes from the official prebuilt release (`whisper-bin-x64.zip`) and is wired in through `HYPERFRAMES_WHISPER_PATH`, since HyperFrames has no Windows installer for it.
  - Windows troubleshooting: execution policy, UAC, missing winget, `WinError 126` (Visual C++ runtime), long paths, antivirus file locks, `ERR_INVALID_ARG_TYPE` from npm, WSL 2 for Docker.

### Changed

- **Breaking:** the macOS skill is renamed `setup-open-montage` → `setup-open-montage-for-mac` (folder and `name`), so the two platform skills read as a pair. Invoke it as `open-montage:setup-open-montage-for-mac`.
- The macOS skill's description sends Windows users to the new skill instead of saying no skill covers Windows. Plugin, marketplace and README descriptions name both platforms.

## 1.3.1 — 2026-10-25

### Removed

- Routing to another video-editing skill from the description's "Don't use when" clause, and the example of reusing a key from it in `services.md`.

## 1.3.0 — 2026-10-25

### Added

- Step 10, optional local extras for HyperFrames, offered once after a clean `verify.sh` run: whisper.cpp (`brew install whisper-cpp`), Kokoro and MusicGen packages (`kokoro-onnx`, `soundfile` in `.venv`), `HYPERFRAMES_PYTHON` in `.env` pointing at the venv Python, and an optional Docker Desktop start with time-limited probes. Instructions and trade-offs live in the new `references/extras.md`; verified on a real install, where `hyperframes doctor` then showed ✓ for whisper-cpp, Kokoro, MusicGen and Docker.
- `hyperframes_doctor.py` runs `make hyperframes-doctor` under a 300-second limit and prints the doctor's ✓/✗ lines, which the final report lists under **Local extras**.
- `write_env.py --set VAR=VALUE` writes one non-secret setting idempotently, keeping `.env` at mode 600; names that look like secrets are refused.
- § Add local extras later for existing installs. The description is shorter (about 930 characters) and gains the triggers "add local extras to OpenMontage", "fix hyperframes doctor in OpenMontage", and Russian triggers for the add-key and extras flows.
- Troubleshooting § Local extras: flaky npm lookup (`runtime_available=False`, 5-second `npm view` limit), `docker info` hanging or returning HTTP 500, a doctor version notice ahead of npm (`make hyperframes-warm` changes nothing), `HYPERFRAMES_PYTHON` pointing at the system Python or overridden by the shell.

### Changed

- `verify.sh` reports the extras: absent ones as `INFO` (not counted), a `HYPERFRAMES_PYTHON` that is unset while Kokoro is installed, points to a missing interpreter or to another Python as `WARN`, never `FAIL`. Python imports, the diarization check, `make preflight`, `npx hyperframes` and `docker info` now all run under a time limit.
- Workflow ends with Step 9 Verify, Step 10 Local extras (optional) and Step 11 Report; the add-key flow runs Steps 9 and 11.
- README and Preconditions name Apple Silicon as the verified platform. `preflight.sh` prints `ARCH arm64|x86_64`, and Step 1 warns Intel users before any sign-up that the Python stack will probably not install (no current PyTorch Intel macOS wheels); troubleshooting covers `No matching distribution found for torch` on Intel. Preconditions list `perl` and `make`.

### Fixed

- Version pin fallback shows `git status --short` and unpushed commits on `main` and waits for consent before `git checkout -B main`, in line with the never-overwrite rule.
- Python version rule: declining to recreate an unsupported `.venv` now stops the install with a defined report instead of failing later in Step 8; SKILL.md Step 7 states this early stop.
- A key the user kept as `unverified` no longer sends Step 9 back to troubleshooting or blocks the extras offer: its `FAIL key` line goes straight to Open issues.
- The Node brief runs `git status --short` after `npm install` and reports changed files in `NOTES`, so a rewritten lockfile is noticed before it blocks the next `git pull --ff-only`.

## 1.2.0 — 2026-10-25

### Changed

- Speaker diarization is fixed with a compatibility layer in `.venv` (`install_compat.py` + `openmontage_whisperx_compat.py`, loaded through a `.pth` file) instead of editing OpenMontage's `tools/analysis/transcriber.py`. The clone stays clean, so `git pull` always fast-forwards. Verified end to end on WhisperX 3.8.6 with a two-speaker recording.
- `verify.sh` checks the compatibility layer instead of the patched file.
- Skill description shortened to about 820 characters, leaving room below the 1024 limit; triggers unchanged.

### Fixed

- The Step 6 re-check could delete the session's own keys: `preflight.sh --keep <STAGING>` leaves the current key file out of `STALE_STAGING`, and Step 6 uses it.
- `install_compat.py` checks the layer in a fresh isolated interpreter, so it tests the installed `.pth` instead of the copy next to the script and leaves no `__pycache__` in the skill folder; it reads the verdict from stdout only, so pyannote warnings on stderr do not hide it; it replaces an outdated copy left by an earlier skill version.
- Python brief: `pip check` never stops the run; its output goes to `NOTES` and the import check always runs.
- The pin fallback uses `git checkout -B main e01dbf4`, so a pinned clone stays on its branch and later updates still fast-forward; the pin is listed under Open issues. Troubleshooting covers `You are not currently on a branch` from older pins.
- `install.md` refers to the admin-install rule by name instead of by number.
- Free space is checked where the install goes: `preflight.sh --folder` prints `DISK OK|LOW` for the install folder's drive, so an install on an external drive is no longer blocked by a full system disk. The system check reports a full home drive as `STATUS LOW_DISK` instead of `STOP`; Step 1 then settles the install folder before any sign-up, so a stop never comes after the user registered at three services. The add-key flow ignores both, so key changes never need free space.
- Step 1 removes leftover key files before acting on `STATUS`, so they are cleaned up even when the run stops.
- The version pin fallback has its own section, `install.md` § Version pin fallback, linked from Step 7 and troubleshooting.

### Removed

- `patch_diarization.py`. Clones patched by earlier versions are restored by the existing guard in `install.md` § OpenMontage before updating.

## 1.1.0 — 2026-10-25

### Removed

- Pexels is no longer collected. Pexels has paused issuing new API keys, so the skill now walks through three services: Hugging Face, Pixabay and ElevenLabs. `check_key.sh` no longer accepts `PEXELS_API_KEY` and `verify.sh` no longer checks it; an existing `PEXELS_API_KEY` line in `.env` is left untouched.

### Changed

- Workflow steps renumbered: services are Steps 2–4, followed by Install folder (5), Toolchain (6), OpenMontage and dependencies (7), Configure .env and WhisperX (8), Verify and report (9). All cross-references in references and scripts updated.

### Fixed

- `write_env.py` stops with `ERROR: staging file not found` instead of a traceback, before touching `.env`, and replaces `export VAR=` lines instead of adding a duplicate.
- Step 8 defines what to do when the venv or the staging file is missing; Step 7 sends Python brief `NOTES` to Open issues.
- `install.md`: declining to discard local edits in an existing clone now has a defined path (keep the clone, report it); the Python brief checks the same imports as `verify.sh` (`faster_whisper`, `whisperx`, `piper`, `fastapi`).
- The key staging file now lives in `~/Library/Caches/open-montage/` (mode 700 folder, mode 600 file) instead of `$TMPDIR`, so a later session finds and removes leftovers even when `TMPDIR` changes; `preflight.sh` also still finds 1.0.0 leftovers in `$TMPDIR`.
- Node brief: a failed `npx hyperframes --version` no longer fails the brief (reported in a new `NOTES` field), matching troubleshooting and `verify.sh`.
- Pinning to the verified OpenMontage/WhisperX versions is now on the failure path (`troubleshooting.md` § Dependencies and Step 7).
- The final report's start hint no longer assumes the Claude Code CLI; README no longer quotes an ElevenLabs price.
- `ask_secret.sh` always runs in the foreground and the agent waits for its result line before validating, so no second hidden dialog opens on a false `MISSING`.
- After every install the user runs (Command Line Tools, Homebrew), Step 6 re-runs `preflight.sh` and takes `CLT` and `BREW_PREFIX` from its output instead of trusting "done".
- Pinned versions and the Homebrew/Terminal rule are stated once; other files point to them.
- PyAV pinned below 19: faster-whisper 1.2.1 does not cap `av`, and av 19 breaks every transcription with `TypeError: open() got an unexpected keyword argument 'metadata_errors'`. The Python brief installs `av<19`, `verify.sh` fails on av 19+, and troubleshooting covers the error; verified versions now list av 18.1.0.
- `verify.sh` HyperFrames check uses `npx --yes hyperframes --version` with a 60-second limit; `npx --no-install` printed nothing on a working install and gave a false WARN.
- Troubleshooting: the pyannote `torchcodec is not installed correctly` warning (Homebrew FFmpeg newer than torchcodec supports) is documented as harmless.

## 1.0.0 — 2026-10-25

### Added

- `setup-open-montage` skill: guided macOS install of OpenMontage with Hugging Face, Pixabay, Pexels and ElevenLabs keys, toolchain install, parallel Python/Node dependency install, `.env` configuration, WhisperX diarization fix and end-to-end verification.
