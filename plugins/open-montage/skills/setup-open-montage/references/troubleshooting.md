# Troubleshooting

Find the symptom, apply the fix, re-run the step's check. First-time handling of `check_key.sh` results is in SKILL.md § Steps 2–4; § Keys covers results that persist after that handling.

Contents: [Keys](#keys) · [Toolchain](#toolchain) · [Dependencies](#dependencies) · [Local extras](#local-extras) · [Verification](#verification)

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
| `No matching distribution found for torch` with a 3.10–3.13 venv on an Intel Mac (`uname -m` prints `x86_64`) | No current PyTorch wheels for Intel macOS (SKILL.md § Step 1 **Status**, `ARCH x86_64`) | No fix in the skill: list it under Open issues |
| `pip install whisperx` fails on `torchcodec` or `av` | Missing FFmpeg libraries | `brew install ffmpeg`, then re-run the whole Python brief (finished steps are skipped by pip) |
| Transcription fails with `TypeError: open() got an unexpected keyword argument 'metadata_errors'` | PyAV 19+ installed; faster-whisper does not cap `av` | `.venv/bin/python -m pip install "av<19"`, then `.venv/bin/python -m pip check` |
| pyannote prints a long `torchcodec is not installed correctly … FFmpeg 4–7` UserWarning | Homebrew FFmpeg is newer than torchcodec supports | Ignore it: WhisperX decodes audio with the `ffmpeg` CLI and hands pyannote an in-memory waveform, so diarization works |
| `npm ERR! EACCES` | npm cache owned by root from an earlier `sudo npm` | The user runs `sudo chown -R $(id -u):$(id -g) ~/.npm`, then re-run the Node brief |
| `npx hyperframes` hangs or fails | Offline or npm registry blocked | Not a blocker: HyperFrames is fetched on first render |
| `git pull --ff-only` refuses | Local changes in the clone | Show `git -C <INSTALL_DIR> status --short` to the user and ask before discarding anything |
| `git pull --ff-only` says `You are not currently on a branch` | The clone was pinned with a plain `git checkout <commit>` | `git -C "<INSTALL_DIR>" switch main`, then pull again |
| A brief keeps failing after the fixes above, on an error none of them covers | Newer upstream OpenMontage or WhisperX broke the install | Apply `install.md` § Version pin fallback |
| `install_compat.py` prints `FAIL` | WhisperX changed its diarization API again | Leave it; diarization is optional. Report it so the user can check upstream OpenMontage and WhisperX issues |

## Local extras

| Symptom | Cause | Fix |
|---|---|---|
| OpenMontage's preflight or `make hyperframes-doctor` says HyperFrames is unavailable (`runtime_available=False`, `npm … not resolvable: timeout (5s)`, "npm did not answer"), while a run minutes later is fine | OpenMontage gives `npm view hyperframes version` only 5 seconds; slow or flaky registry lookups miss it | Transient, nothing to reinstall: run `hyperframes_doctor.py` once more. If it repeats, list it under Open issues; Remotion still covers titles and captions |
| `docker info` hangs, or returns `500 Internal Server Error` | Docker Desktop is still starting, or waits for its first-run window (terms, sign-in, survey) | Ask the user to finish or skip that window, then probe again with the 20-second limit. If it persists, the user quits and reopens Docker Desktop. The three-probe limit in SKILL.md § Step 10 applies |
| Doctor flags a newer HyperFrames (`0.8.185 → 0.8.197 available`) and `make hyperframes-warm` changes nothing | The doctor's notice can be ahead of npm: on 2026-10-25 npm's `latest` was 0.8.185 and 0.8.197 was not published | `cd "<INSTALL_DIR>" && perl -e 'alarm 30; exec @ARGV' npm view hyperframes dist-tags --json`. If `latest` equals the installed version, it is not an issue: do not list it. If `latest` is newer, `cd "<INSTALL_DIR>" && perl -e 'alarm 60; exec @ARGV' npx --yes hyperframes@latest --version` should fetch it (not verified yet: npm had nothing newer during verification) |
| Doctor shows ✗ for Kokoro or MusicGen although the packages are in `.venv` | `HYPERFRAMES_PYTHON` is unset or points at the system Python, so HyperFrames looks in the wrong interpreter | Run the `write_env.py --set` command from `extras.md` § Install, item 3, then the doctor again |
| Doctor still shows the old interpreter after fixing `.env` | `HYPERFRAMES_PYTHON` is also exported in the shell; OpenMontage lets the environment win over `.env` | Ask the user to remove the `export HYPERFRAMES_PYTHON=…` line from their shell profile and open a new terminal |
| `brew install whisper-cpp` fails with a lock error | Another brew process is running | Wait for it, then re-run the same command |
| `pip install kokoro-onnx` moves `av` to 19 or newer | A dependency upgrade pulled a newer PyAV | Apply § Dependencies, `metadata_errors` row |

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
| `WARN diarization FAIL: compatibility layer not installed …` | Run the `install_compat.py` command from SKILL.md § Step 8 |
| `WARN diarization SKIP: …` | WhisperX is not installed: re-run the Python brief |
| `WARN diarization FAIL: …` (other) or `compat check did not run` | WhisperX changed again or `.venv` is broken: report it as an open issue; diarization is optional |
| `FAIL preflight` | Run `make preflight` in `<INSTALL_DIR>` and show the user the last 20 lines; if the target no longer exists upstream, report it as an open issue. If it only timed out, see § Local extras, `runtime_available=False` row |
| `INFO whisper-cpp/kokoro/musicgen/docker …` or `INFO hyperframes-python … not set` | Optional local extra not set up: nothing to fix. Offer SKILL.md § Add local extras later if the user wants it |
| `WARN hyperframes-python …` (not set while Kokoro is installed, missing interpreter, or not the `.venv` Python) | Run the `write_env.py --set` command from `extras.md` § Install, item 3; it replaces the old line |
