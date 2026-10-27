# Local extras for HyperFrames

Verified on 2026-10-25 against OpenMontage `e01dbf4` and HyperFrames 0.8.185 on Apple Silicon: after these steps `hyperframes doctor` showed ✓ for whisper-cpp, Kokoro, MusicGen and Docker. Re-verify this file whenever the OpenMontage pin in `install.md` moves. Write literal absolute paths in place of `<INSTALL_DIR>`, `<SKILL_DIR>` and `<BREW_PREFIX>`; start every command with the Homebrew `shellenv` line (SKILL.md § Critical rules).

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

Only on "yes" to local extras. Run in order; a failure in one item goes under Open issues and the next item still runs.

1. **whisper.cpp** (binary `<BREW_PREFIX>/bin/whisper-cli`). Homebrew runs one install at a time:
   ```bash
   brew install whisper-cpp
   ```
2. **Kokoro and MusicGen packages.** MusicGen needs transformers, torch, numpy and soundfile; WhisperX already brought the first three, so only soundfile is new:
   ```bash
   cd "<INSTALL_DIR>" && .venv/bin/python -m pip install kokoro-onnx soundfile && .venv/bin/python -m pip check; .venv/bin/python -c "import av; print(av.__version__)"
   ```
   `pip check` output goes under Open issues if it is not `No broken requirements found.` An av version of 19 or newer: apply `troubleshooting.md` § Dependencies, `metadata_errors` row.
3. **Point HyperFrames at the venv.** HyperFrames looks for Python in `HYPERFRAMES_PYTHON`, otherwise takes the first `python3` on `PATH` (the system Python, which lacks these packages). OpenMontage loads `.env` into its environment at start (`tools/base_tool.py`), so HyperFrames subprocesses inherit the setting. The script keeps `.env` at mode 600, replaces an earlier `HYPERFRAMES_PYTHON` line instead of adding a second one, and prints only the variable name:
   ```bash
   cd "<INSTALL_DIR>" && .venv/bin/python "<SKILL_DIR>/scripts/write_env.py" "<INSTALL_DIR>/.env" --set "HYPERFRAMES_PYTHON=<INSTALL_DIR>/.venv/bin/python"
   ```
   Expected: `SET: HYPERFRAMES_PYTHON`.

## Docker

Only on "yes" to Docker. Every `docker` call gets a 20-second limit: while Docker Desktop starts or waits for its first-run window, `docker info` hangs or returns HTTP 500.

1. **Installed?** `ls -d /Applications/Docker.app`. If it is missing, tell the user Docker Desktop is not installed, that installing it is their own choice (https://www.docker.com/products/docker-desktop/), and continue with § Doctor.
2. **Probe.** Docker Desktop also installs the CLI at the path below, which works before `/usr/local/bin/docker` exists:
   ```bash
   perl -e 'alarm 20; exec @ARGV' /Applications/Docker.app/Contents/Resources/bin/docker info >/dev/null 2>&1 && echo RUNNING || echo NOT_RUNNING
   ```
   `RUNNING` → continue with § Doctor.
3. **Start.** `open -a Docker`, then tell the user: "Docker Desktop is starting. If a window asks you to accept the terms, sign in or answer a survey, finish or skip it, then tell me." Wait for their reply, then probe again.
4. **Bounded retries.** Follow the Docker limit in SKILL.md § Step 10; `troubleshooting.md` § Local extras covers a hang or HTTP 500.

## Doctor

Run after § Install and § Docker, even if some items failed. The script runs `make hyperframes-doctor` under a 300-second limit and decodes its JSON (use a tool timeout of at least 6 minutes):

```bash
cd "<INSTALL_DIR>" && .venv/bin/python "<SKILL_DIR>/scripts/hyperframes_doctor.py" "<INSTALL_DIR>"
```

Then act on its `RESULT` line as in SKILL.md § Step 10.
