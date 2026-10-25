# Install commands

Verified as of 2026-10 against OpenMontage `main` at commit `e01dbf4` (2026-10-24), WhisperX 3.8.6, faster-whisper 1.2.1 with PyAV (`av`) 18.1.0, uv 0.10 and HyperFrames on Node.js 22+. PyAV must stay below 19: av 19 removed an argument faster-whisper still passes, and faster-whisper does not cap it, so the Python brief pins `av<19`. The skill installs the latest upstream versions on purpose, so users get current fixes; if that breaks, apply § Version pin fallback. If upstream requirements change, OpenMontage's README and `Makefile` are the source of truth; `verify.sh` relies on the Makefile's `preflight` target.

Write literal absolute paths in place of `<INSTALL_DIR>` and `<BREW_PREFIX>`. Admin installs, the Homebrew prefix and long-command timeouts follow SKILL.md § Critical rules.

Contents: [Toolchain](#toolchain) · [OpenMontage](#openmontage) · [Sub-agent briefs](#sub-agent-briefs) · [Version pin fallback](#version-pin-fallback)

## Toolchain

Run in order. Skip any item whose check already passes.

1. **Command Line Tools** (Xcode; provides `git`, `make`, compilers).
   - Check: `xcode-select -p`
   - If missing, the user runs `xcode-select --install`, accepts the macOS dialog and tells you when it finishes (5–15 minutes).
2. **Homebrew.**
   - Check: `ls <BREW_PREFIX>/bin/brew` for `/opt/homebrew` (Apple Silicon) or `/usr/local` (Intel).
   - If missing, the user pastes this into Terminal.app (SKILL.md § Critical rules, **Admin and interactive installs are the user's**):
     ```text
     /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
     ```
   - From here on, the Homebrew rule in SKILL.md § Critical rules applies to every command.
3. **Formulae** (git, uv, FFmpeg, Node.js) — one command; Homebrew cannot run two installs at once, so never split this across sub-agents:
   ```bash
   brew install git uv ffmpeg node
   ```
   Already-installed formulae are skipped.
4. **Node.js version.** `node --version` must be v22 or newer (HyperFrames requirement). If older: `brew upgrade node`.
5. **Python.** No system install needed: `uv` downloads Python into its own cache in the next section. The version rule lives in § OpenMontage, **Python version rule**.

## OpenMontage

Fresh install:

```bash
git clone https://github.com/calesthio/OpenMontage "<INSTALL_DIR>"
```

Existing clone (reinstall or update). Installs made by skill versions before 1.2.0 edited one tracked file to fix diarization, which blocks the pull; current versions leave the repo untouched. First check that the file holds at most that old edit — this prints nothing when it does:

```bash
git -C "<INSTALL_DIR>" diff -U0 -- tools/analysis/transcriber.py | grep -E '^[+-][^+-]' | grep -vE 'DiarizationPipeline|hf_token'
```

- **No output** → restore the file and update; Step 8 installs the compatibility layer that replaces the old edit:
  ```bash
  git -C "<INSTALL_DIR>" checkout -- tools/analysis/transcriber.py && git -C "<INSTALL_DIR>" pull --ff-only
  ```
- **Any output** → the user edited the file. Show them `git -C "<INSTALL_DIR>" diff --stat` and ask before discarding anything. If they agree, run the **No output** command. If they decline, skip the update, keep the clone as it is, continue with the Python version rule below and list "OpenMontage not updated: local edits kept" under Open issues in the report.

If the pull still refuses, see `troubleshooting.md` § Dependencies.

**Python version rule.** The venv must run Python 3.10–3.13: WhisperX supports exactly that range and torch has no wheels beyond it. New venvs use 3.12. Create one only if none exists (uv refuses to overwrite an existing `.venv`):

```bash
cd "<INSTALL_DIR>" && { [ -x .venv/bin/python ] || uv venv --seed --python 3.12 .venv; } && .venv/bin/python --version
```

`--seed` puts `pip` into the venv; OpenMontage's Makefile calls `python -m pip`.

Check: the version printed is 3.10–3.13. If an existing `.venv` reports anything else, ask the user, then recreate it — `--clear` deletes the old environment:

```bash
cd "<INSTALL_DIR>" && uv venv --clear --seed --python 3.12 .venv
```

## Sub-agent briefs

Launch both at once, each as its own sub-agent, with `<INSTALL_DIR>` and `<BREW_PREFIX>` replaced by literal paths.

### Brief: Python stack

```text
Install OpenMontage's Python dependencies into an existing virtual environment on macOS.

Folder: <INSTALL_DIR>  (an OpenMontage git clone; .venv already exists with Python 3.10–3.13)
Every shell call starts fresh: begin EVERY command with
  cd "<INSTALL_DIR>" && eval "$(<BREW_PREFIX>/bin/brew shellenv)";
Each install can take several minutes: use a timeout of at least 10 minutes per command.

Run in order. Stop at the first failure in steps 1–5 or 7; step 6 never stops the run:
1. .venv/bin/python -m pip install -r requirements.txt
2. .venv/bin/python -m pip install piper-tts
3. .venv/bin/python -m pip install faster-whisper
4. .venv/bin/python -m pip install whisperx
5. .venv/bin/python -m pip install "av<19"
6. .venv/bin/python -m pip check
7. .venv/bin/python -c "import faster_whisper, whisperx, piper, fastapi; print('imports ok')"

Rules:
- Do not touch .env, do not read or print any API keys, do not edit files in the repo.
- Do not install anything outside .venv and do not use sudo.
- Step 6 (pip check) may exit non-zero on harmless version conflicts: always continue to step 7 and put its output in NOTES.

Return exactly:
STATUS: OK | FAILED
FAILED_COMMAND: <command or "none">
NOTES: <pip check warnings or "none">
LAST_ERROR_LINES: <last 20 lines of output on failure, otherwise "none">
```

### Brief: Node stack

```text
Install OpenMontage's Node.js dependencies on macOS.

Folder: <INSTALL_DIR>  (an OpenMontage git clone; Node.js 22+ is installed via Homebrew)
Every shell call starts fresh: begin EVERY command with
  cd "<INSTALL_DIR>" && eval "$(<BREW_PREFIX>/bin/brew shellenv)";
Use a timeout of at least 10 minutes per command.

Run in order:
1. cd remotion-composer && npm install   (on failure, stop and return STATUS: FAILED)
2. npx --yes hyperframes --version   (on failure, keep STATUS: OK and describe it in NOTES:
   HyperFrames is fetched again on first render)

Rules:
- Do not touch .env, do not read or print any API keys, do not edit files in the repo.
- Do not use sudo or global npm installs.

Return exactly:
STATUS: OK | FAILED
FAILED_COMMAND: <command or "none">
HYPERFRAMES_VERSION: <version printed by step 2 or "none">
NOTES: <step 2 failure in one line, or "none">
LAST_ERROR_LINES: <last 20 lines of output on failure, otherwise "none">
```

## Version pin fallback

Use only when a brief keeps failing on a newer upstream after the fixes in `troubleshooting.md` § Dependencies. Pin OpenMontage and WhisperX to the verified versions from the intro:

```bash
git -C "<INSTALL_DIR>" checkout -B main e01dbf4 && cd "<INSTALL_DIR>" && .venv/bin/python -m pip install whisperx==3.8.6
```

`-B main` keeps the clone on its branch, so a later `git pull --ff-only` still updates it. Re-run the failed brief, tell the user which versions are pinned and list the pin under Open issues in the report.
