# Troubleshooting

Find the symptom, apply the fix, re-run the step's check. First-time handling of `check_key.sh` results is in SKILL.md § Steps 2–4; § Keys covers results that persist after that handling.

Contents: [Keys](#keys) · [Toolchain](#toolchain) · [Dependencies](#dependencies) · [Verification](#verification)

## Keys

| Symptom | Cause | Fix |
|---|---|---|
| `ERROR: osascript dialog unavailable` | No GUI session (SSH, remote, headless client) | Use `--from-file`: the user saves the key to a text file and names the path |
| `ERROR: … has several lines and no <VAR>= line` or `… holds a different VAR= line` | The named file is not a key file for this service | Ask for a file with only the key, or one with a `<VAR>=` line |
| `ERROR: file not found or empty` | Wrong path or empty file | Ask the user for the exact path (`~` is allowed) |
| `ERROR: … VAR= line is empty` | The file has the variable but no value (e.g. a copy of `.env.example`) | Ask for the file that holds the real key, or use the dialog |
| `HF_TOKEN` stays `INVALID` with a correct-looking token | Fine-grained token without read access to public repos | Create a token of type **Read** |
| `NOT_ACCEPTED` after the user accepted | Accepted with a different Hugging Face account than the token's | Accept the model terms while signed in to the token's account |
| `NOT_ACCEPTED` with the right account | Fine-grained token without access to gated repositories | Create a token of type **Read**, or enable "Read access to contents of all public gated repos" on the fine-grained token |

## Toolchain

| Symptom | Cause | Fix |
|---|---|---|
| `brew: command not found` right after installing Homebrew | Fresh shell without Homebrew on `PATH` | Apply the Homebrew rule from SKILL.md § Critical rules; ask the user to add the `shellenv` line to `~/.zprofile` as the installer suggests |
| `xcode-select: note: install requested` but nothing finishes | macOS dialog waiting behind other windows | Ask the user to find and accept the "Command Line Tools" dialog |
| `brew install` fails with a lock error | Another brew process is running | Wait for it, then re-run the same single `brew install` |
| `node --version` below v22 | Another Node (nvm, nodejs.org installer) earlier in `PATH` | `brew upgrade node`, then `command -v node`; if it is not under `<BREW_PREFIX>`, tell the user which Node shadows it |

## Dependencies

| Symptom | Cause | Fix |
|---|---|---|
| `No module named pip` | venv created without `--seed` | Recreate it with the `--clear` command in `install.md` § OpenMontage, **Python version rule** |
| `A virtual environment already exists at .venv` | `uv venv` run over an existing venv | Apply `install.md` § OpenMontage, **Python version rule** |
| `No matching distribution found for torch` | venv Python outside the supported range | Apply `install.md` § OpenMontage, **Python version rule** |
| `pip install whisperx` fails on `torchcodec` or `av` | Missing FFmpeg libraries | `brew install ffmpeg`, then re-run the whole Python brief (finished steps are skipped by pip) |
| Transcription fails with `TypeError: open() got an unexpected keyword argument 'metadata_errors'` | PyAV 19+ installed; faster-whisper does not cap `av` | `.venv/bin/python -m pip install "av<19"`, then `.venv/bin/python -m pip check` |
| pyannote prints a long `torchcodec is not installed correctly … FFmpeg 4–7` UserWarning | Homebrew FFmpeg is newer than torchcodec supports | Ignore it: WhisperX decodes audio with the `ffmpeg` CLI and hands pyannote an in-memory waveform, so diarization works |
| `npm ERR! EACCES` | npm cache owned by root from an earlier `sudo npm` | The user runs `sudo chown -R $(id -u):$(id -g) ~/.npm`, then re-run the Node brief |
| `npx hyperframes` hangs or fails | Offline or npm registry blocked | Not a blocker: HyperFrames is fetched on first render |
| `git pull --ff-only` refuses | Local changes in the clone | Show `git -C <INSTALL_DIR> status --short` to the user and ask before discarding anything |
| A brief keeps failing after the fixes above, on an error none of them covers | Newer upstream OpenMontage or WhisperX broke the install | Pin to the verified versions as described in the `install.md` intro, re-run the failed brief, and tell the user which version is pinned |
| `patch_diarization.py` prints `FAIL` | OpenMontage or WhisperX changed the diarization code | Leave it; diarization is optional. Report it so the user can check upstream OpenMontage issues |

## Verification

| `verify.sh` line | Fix |
|---|---|
| `FAIL macos` | Unsupported system; stop and tell the user |
| `FAIL homebrew/git/uv/ffmpeg not found` or `FAIL git Command Line Tools missing` | Repeat SKILL.md § Step 6 for the missing tool |
| `FAIL node … (need v22+)` | See § Toolchain, `node --version` row |
| `FAIL node not found` | Repeat SKILL.md § Step 6 (`install.md` § Toolchain, **Formulae**) |
| `WARN hyperframes not available…` | Not a blocker: HyperFrames is fetched on first render. Optionally re-run the Node brief |
| `FAIL openmontage no git clone at …` | Repeat SKILL.md § Step 7 **Clone** |
| `FAIL env no .env in …` | Re-run the `write_env.py` command from SKILL.md § Step 8 (with a new staging file if the old one is gone) |
| `FAIL python …` | Apply `install.md` § OpenMontage, **Python version rule**, then re-run the Python brief |
| `FAIL import <module>` | Re-run the Python brief; read its `LAST_ERROR_LINES` |
| `FAIL av …` | `.venv/bin/python -m pip install "av<19"` (see § Dependencies, `metadata_errors` row) |
| `FAIL remotion …` | Re-run the Node brief |
| `FAIL env permissions` | `chmod 600 <INSTALL_DIR>/.env` |
| `WARN env <VAR> not set` | The service was skipped; offer SKILL.md § Add or replace a key later |
| `FAIL key <VAR>: NOT_ACCEPTED` or `NO_PERMISSION` | Same action as that result in the SKILL.md § Steps 2–4 table, then re-run `verify.sh`; the key itself stays |
| `FAIL key <VAR>: INVALID` or `MISSING` | Offer SKILL.md § Add or replace a key later for that service |
| `FAIL key <VAR>: UNEXPECTED_HTTP_<code>` | Re-run `verify.sh` once; if it repeats, report it as unverified with the code |
| `WARN key <VAR>: UNREACHABLE` | Network issue; not a blocker. Suggest retrying later or with a VPN |
| `WARN diarization NEEDS_PATCH: …` | Run the `patch_diarization.py` command from SKILL.md § Step 8 |
| `WARN diarization SKIP: …` | WhisperX is not installed: re-run the Python brief |
| `WARN diarization FAIL: …` or `patch check did not run` | Upstream code changed or `.venv` is broken: report it as an open issue; diarization is optional |
| `FAIL preflight` | Run `make preflight` in `<INSTALL_DIR>` and show the user the last 20 lines; if the target no longer exists upstream, report it as an open issue |
