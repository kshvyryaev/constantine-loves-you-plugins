# Changelog

## 1.2.0 — 2026-10-25

### Changed

- Speaker diarization is fixed with a compatibility layer in `.venv` (`install_compat.py` + `openmontage_whisperx_compat.py`, loaded through a `.pth` file) instead of editing OpenMontage's `tools/analysis/transcriber.py`. The clone stays clean, so `git pull` always fast-forwards. Verified end to end on WhisperX 3.8.6 with a two-speaker recording.
- `verify.sh` checks the compatibility layer instead of the patched file.

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
