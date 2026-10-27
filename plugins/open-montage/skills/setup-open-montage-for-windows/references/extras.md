# Local extras for HyperFrames

Ported from the macOS flow, which was verified on 2026-10-25 against OpenMontage `e01dbf4` and HyperFrames 0.8.185. The Windows parts follow HyperFrames 0.8.192's own lookup code — whisper.cpp through `HYPERFRAMES_WHISPER_PATH`, then `whisper-cli` on `PATH` (HyperFrames has no Windows installer for it); Python through `HYPERFRAMES_PYTHON`, then the first `python3` or `python` on `PATH`; Docker through `docker` on `PATH` — (Windows verification status: SKILL.md intro). Write literal absolute paths in place of `<INSTALL_DIR>` and `<SKILL_DIR>`.

Contents: [The offer](#the-offer) · [Install](#install) · [Docker](#docker) · [Doctor](#doctor)

## The offer

Send this once, in the user's language, as one message with two questions:

> OpenMontage works now. HyperFrames' own check (`hyperframes doctor`) also looks for optional local engines. OpenMontage already covers these jobs without them: faster-whisper for transcription, Piper or ElevenLabs for voice, ElevenLabs or Pixabay for music.
>
> - **Local extras** (whisper.cpp transcription, Kokoro offline voice, MusicGen offline music): a few minutes to install. The Kokoro model (~300 MB) and the MusicGen weights (1.5–3 GB) download the first time they are used, and MusicGen is slow without a GPU.
> - **Docker** (isolated rendering): only starts Docker Desktop if it is already installed; it keeps several GB of RAM in use while running.
>
> Install the local extras? Start Docker? (yes/no for each)

## Install

Only on "yes" to local extras. Run in order; SKILL.md § Step 10 says what happens when an item fails.

1. **whisper.cpp.** Downloads the official prebuilt CLI from the whisper.cpp GitHub releases into `%LOCALAPPDATA%\open-montage\whisper.cpp` (about 25 MB; nothing is added to `PATH`):
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File "<SKILL_DIR>\scripts\install_whisper.ps1"
   ```
   Expected: `WHISPER_CLI <path>` and `RELEASE <tag>`. Then point HyperFrames at it (replaces an earlier line instead of adding a second one):
   ```powershell
   Set-Location "<INSTALL_DIR>"; .\.venv\Scripts\python.exe "<SKILL_DIR>\scripts\write_env.py" "<INSTALL_DIR>\.env" --set "HYPERFRAMES_WHISPER_PATH=<WHISPER_CLI path>"
   ```
   Expected: `SET: HYPERFRAMES_WHISPER_PATH`. An `ERROR` from `install_whisper.ps1`: `troubleshooting.md` § Local extras. An `ERROR` from `write_env.py`: the same handling as in SKILL.md § Step 8 (`could not restrict` is in `troubleshooting.md` § Keys).
2. **Kokoro and MusicGen packages.** MusicGen needs transformers, torch, numpy and soundfile; WhisperX already brought the first three, so only soundfile is new:
   ```powershell
   Set-Location "<INSTALL_DIR>"; $env:PYTHONUTF8="1"; .\.venv\Scripts\python.exe -m pip install kokoro-onnx soundfile; "EXIT $LASTEXITCODE"; .\.venv\Scripts\python.exe -m pip check; .\.venv\Scripts\python.exe -c "import av; print(av.__version__)"
   ```
   The item failed if `EXIT` is not 0: show the last pip error lines and check `troubleshooting.md` § Dependencies. `pip check` output goes under Open issues if it is not `No broken requirements found.` An av version of 19 or newer: apply `troubleshooting.md` § Dependencies, `metadata_errors` row.
3. **Point HyperFrames at the venv.** Without `HYPERFRAMES_PYTHON`, HyperFrames takes the first `python3` or `python` on `PATH`: a system Python without these packages, or the Microsoft Store alias that only opens the Store. OpenMontage loads `.env` into its environment at start (`tools/base_tool.py`), so HyperFrames subprocesses inherit the setting:
   ```powershell
   Set-Location "<INSTALL_DIR>"; .\.venv\Scripts\python.exe "<SKILL_DIR>\scripts\write_env.py" "<INSTALL_DIR>\.env" --set "HYPERFRAMES_PYTHON=<INSTALL_DIR>\.venv\Scripts\python.exe"
   ```
   Expected: `SET: HYPERFRAMES_PYTHON`.

## Docker

Only on "yes" to Docker. The probe gives `docker info` a 20-second limit: while Docker Desktop starts or waits for its first-run window, `docker info` hangs or returns HTTP 500.

1. **Probe.**
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File "<SKILL_DIR>\scripts\docker_probe.ps1"
   ```
   `DOCKER RUNNING` → continue with § Doctor. `DOCKER NOT_INSTALLED` → tell the user Docker Desktop is not installed, that installing it is their own choice (https://www.docker.com/products/docker-desktop/; it also needs WSL 2), and continue with § Doctor.
2. **Start.** On `DOCKER NOT_RUNNING`, run the same script with `-Start`, then tell the user: "Docker Desktop is starting. If a window asks you to accept the terms, sign in, answer a survey or finish WSL setup, finish or skip it, then tell me." Wait for their reply, then probe again.
3. **Bounded retries.** Follow the Docker limit in SKILL.md § Step 10; `troubleshooting.md` § Local extras covers a hang, HTTP 500 and WSL errors.

## Doctor

Run after § Install and § Docker, even if some items failed. The script runs OpenMontage's HyperFrames doctor under a 300-second limit and decodes its JSON (use a tool timeout of at least 6 minutes):

```powershell
Set-Location "<INSTALL_DIR>"; .\.venv\Scripts\python.exe "<SKILL_DIR>\scripts\hyperframes_doctor.py" "<INSTALL_DIR>"
```

Keep every `DOCTOR` line (the ✓/✗ checks) for the report; label a ✗ for something the user declined "not set up (declined)". Act on the `RESULT` line:

| Result | Action |
|---|---|
| `RESULT OK` | Done |
| `RESULT FAIL …` with `REASON … not resolvable: timeout (5s)` | Flaky npm lookup: `troubleshooting.md` § Local extras, `runtime_available=False` row |
| `RESULT FAIL …` (other) | Apply `troubleshooting.md` § Local extras; list what remains under Open issues |
| `RESULT TIMEOUT 300 s` | Run once more; if it repeats, list "hyperframes doctor did not finish" under Open issues |
| `RESULT NO_TARGET` or `RESULT ERROR …` | OpenMontage changed or removed the HyperFrames tool: list it under Open issues |

A `DOCTOR` line announcing a newer HyperFrames is checked against npm first (`troubleshooting.md` § Local extras, "newer HyperFrames" row); it is often not an issue.
