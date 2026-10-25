---
name: setup-open-montage
description: >
  Guided macOS install of OpenMontage, the agentic video studio: Hugging Face, Pixabay and
  ElevenLabs sign-ups one at a time, API keys kept out of chat, verified end to end. Also adds or
  replaces keys in an existing install and adds optional local HyperFrames extras.
  Use when user says "install OpenMontage", "set up OpenMontage", "configure OpenMontage",
  "reinstall OpenMontage", "add keys to OpenMontage", "add local extras to OpenMontage",
  "fix hyperframes doctor in OpenMontage", "установи OpenMontage", "настрой OpenMontage",
  "добавь ключи в OpenMontage", "поставь локальные дополнения OpenMontage".
  Don't use when: user wants to produce a video with an existing OpenMontage install (no skill:
  start Claude inside the OpenMontage folder), user is on Windows or Linux or asks to uninstall
  OpenMontage (no skill covers these; tell the user).
metadata:
  version: 1.3.1
  author: kshvyryaev
---

# Setup OpenMontage

Guide the user from an empty Mac to a verified OpenMontage install with every agreed service configured. The user does the sign-ups; you do everything else.

## File map

| File | Read when |
|---|---|
| `references/services.md` | Steps 2–4: sign-up steps, key settings, what each key enables |
| `references/install.md` | Steps 6–7: toolchain commands, Python version rule, the two sub-agent briefs |
| `references/extras.md` | Step 10: the extras offer, install commands, Docker start, doctor results |
| `references/troubleshooting.md` | A command fails, or a result is not covered by the tables in this file |
| `scripts/preflight.sh` | Steps 1 and 5: system check, leftover key files, install-folder classification |
| `scripts/ask_secret.sh` | Steps 2–4: capture a key into the staging file without showing it |
| `scripts/check_key.sh` | Steps 2–4: validate one key against its service |
| `scripts/write_env.py` | Steps 8 and 10: merge staged keys, or one non-secret setting, into `.env` |
| `scripts/install_compat.py` | Steps 8–9: install or check the WhisperX compatibility layer in `.venv` |
| `scripts/openmontage_whisperx_compat.py` | Never read it into context: `install_compat.py` copies it into `.venv` |
| `scripts/verify.sh` | Steps 9 and 11: full install check, extras included |
| `scripts/hyperframes_doctor.py` | Step 10: run `make hyperframes-doctor` with a time limit and print its checks |

## Preconditions

- macOS 13 or newer, and at least 10 GB free on the install folder's drive for a new install (`preflight.sh` checks both; adding keys needs no free space).
- Internet access.
- The user can enter their Mac admin password (Homebrew and Xcode Command Line Tools ask for it).
- A GUI login session for the hidden key dialog. Over SSH or in a headless client, every key must come from a file (`--from-file`).
- A shell tool is available. Without it, stop and tell the user the skill cannot run here.
- Apple Silicon is the verified platform; Step 1 **Status** covers Intel Macs.
- `perl` (ships with macOS) for time limits; `make` comes with the Command Line Tools from Step 6.

## Critical rules

1. **Keys never pass through chat.** Never ask the user to paste a key into the conversation, and never print, echo, `cat` or log a key. Keys enter only through `ask_secret.sh` (hidden macOS dialog, or a file the user names). If the user pastes a key into chat anyway, do not reuse it: tell them to revoke it and create a new one.
2. **No key file outlives the session.** Whenever the workflow stops — finished, aborted, or the user quits midway — run `rm -f <STAGING>` and say in your last message that it was removed. Key files left by an earlier interrupted session are removed in Step 1.
3. **Use literal paths.** Every tool call may start a fresh shell, so shell variables do not carry over. Write the absolute values of `SKILL_DIR`, `STAGING`, `INSTALL_DIR` and `BREW_PREFIX` from the State block into every command, and quote them — paths may contain spaces. `SKILL_DIR` is the directory containing this `SKILL.md`.
4. **Load Homebrew in every shell.** Once Homebrew exists, start every shell command with `eval "$(<BREW_PREFIX>/bin/brew shellenv)";` — otherwise `brew`, `uv`, `node` and `ffmpeg` are not found in a fresh shell.
5. **One service at a time.** Finish a service (key saved and checked, or explicitly skipped) before introducing the next.
6. **Admin and interactive installs are the user's.** Give the exact command and wait until the user confirms it finished. The Homebrew installer asks for the admin password in a terminal, so it always goes to Terminal.app. `xcode-select --install` only opens a macOS dialog: in Claude Code the user may run it with the `!` prefix, in other clients in Terminal.app.
7. **Long commands get a long timeout** (10 minutes or more). `ask_secret.sh` always runs in the foreground (its dialog waits up to 10 minutes); a tool timeout on it counts as `CANCELLED`. `brew install`, `pip install`, `npm install` and the sub-agent briefs may also run in the background.
8. **Never overwrite foreign data.** An existing install folder is reused only if it is an OpenMontage git clone; any other non-empty folder means asking for a different path. Local edits inside a clone are discarded only with the user's consent.
9. **No success without evidence.** The final report comes only from `verify.sh` output, plus the `hyperframes_doctor.py` lines for local extras.
10. **Speak the user's language.** Commands, file names and env var names stay as they are.

## Progress checklist

Post this after Step 1 and repost it, updated, at every step boundary. The State block is the session memory: keep it current.

```text
OpenMontage setup:
- [ ] 1. Preflight
- [ ] 2. Hugging Face (HF_TOKEN)
- [ ] 3. Pixabay (PIXABAY_API_KEY)
- [ ] 4. ElevenLabs (ELEVENLABS_API_KEY)
- [ ] 5. Install folder
- [ ] 6. Toolchain
- [ ] 7. OpenMontage and dependencies
- [ ] 8. Configure .env and WhisperX
- [ ] 9. Verify
- [ ] 10. Local extras (optional)
- [ ] 11. Report

State:
- SKILL_DIR: <absolute path>
- STAGING: <absolute path>
- INSTALL_DIR: <not chosen yet>
- BREW_PREFIX: </opt/homebrew | /usr/local | not installed>
- Services: HF=<pending|OK|unverified|skipped> Pixabay=<…> ElevenLabs=<…>
```

**Completion gate:** do not send the final report while any checklist item is neither done, explicitly skipped by the user, nor listed under Open issues in the report.

## Workflow

### Step 1 — Preflight

- **Probe.** Run `bash "/abs/SKILL_DIR/scripts/preflight.sh"`. Never probe `git` or `python3` with `command -v`: without Command Line Tools they are stubs that look installed and can open the installer — `preflight.sh` avoids them.
- **Leftover keys.** Do this before acting on `STATUS`, even on `STOP`. For every `STALE_STAGING <path>` line, tell the user a key file from an interrupted earlier run was found and remove it with `rm -f "<path>"`.
- **Status.** `STATUS STOP <reason>` (not macOS 13+): tell the user the reason and stop. `ARCH x86_64` (Intel Mac): before any sign-up, tell the user the install is verified only on Apple Silicon and the Python stack (WhisperX) will probably fail to install because PyTorch has no current Intel macOS wheels; continue only if they agree, otherwise stop. `STATUS LOW_DISK <reason>`: the home folder's drive is short on space. Tell the user and run Step 5 now, before any sign-up, so a stop never comes after Steps 2–4. The add-key and local-extras flows ignore `LOW_DISK` and `ARCH`.
- **Staging file.** Create the private key file in a fixed per-user folder (so a later session finds it even if `TMPDIR` changes) and note its printed path as `STAGING`:
  ```bash
  mkdir -p "$HOME/Library/Caches/open-montage" && chmod 700 "$HOME/Library/Caches/open-montage" && STAGING=$(mktemp "$HOME/Library/Caches/open-montage/keys.XXXXXX") && chmod 600 "$STAGING" && echo "$STAGING"
  ```
- **State block.** Fill it: `BREW_PREFIX` comes from the probe's `BREW_PREFIX` line.
- **Summary.** Tell the user in 2–3 lines what is already installed (`CLT`, `TOOL` lines), what will be installed, and that the next steps are three short sign-ups.

### Steps 2–4 — Services

Order: Hugging Face → Pixabay → ElevenLabs. For each service, read its section in `references/services.md`, then:

- **Instruct.** Give the user the numbered sign-up and key-creation steps from that section, including the required key settings.
- **Hand-over.** Ask how they will hand over the key: **hidden dialog** (default) or **path to a file** holding either the bare key on one line or a `VAR=value` line (an existing `.env` works).
- **Capture.**
  ```bash
  bash "/abs/SKILL_DIR/scripts/ask_secret.sh" HF_TOKEN "/abs/STAGING" "Paste your Hugging Face token"
  # or, if the user named a file:
  bash "/abs/SKILL_DIR/scripts/ask_secret.sh" HF_TOKEN "/abs/STAGING" --from-file "/Users/me/Documents/hf-token.txt"
  ```
  Wait for its result line before **Validate**. Expected: `SAVED: <VAR> (<n> chars)`. `CANCELLED`: the dialog was closed, left empty or timed out — ask the user and capture again. `ERROR`: follow `references/troubleshooting.md` § Keys.
- **Validate.** `bash "/abs/SKILL_DIR/scripts/check_key.sh" <VAR> "/abs/STAGING"`, then act on the result and update the State block:

| Result | Action |
|---|---|
| `OK` | Service done |
| `INVALID` | The service rejected the key. Capture again; if it repeats, check `references/troubleshooting.md` § Keys; after two failed retries offer to skip |
| `NOT_ACCEPTED` | Hugging Face only: pyannote model terms not accepted. Send the model link from `references/services.md`, wait for confirmation, validate again. If it repeats, check `references/troubleshooting.md` § Keys; after two re-checks offer to skip or keep the key as `unverified` |
| `NO_PERMISSION` | ElevenLabs only: the key lacks a required permission. Show the permission list from `references/services.md` again, wait, validate again. After two re-checks offer to skip or keep the key as `unverified` |
| `UNREACHABLE` | The service could not be reached from this network. Keep the key, mark it `unverified`, move on |
| `UNEXPECTED_HTTP_<code>` | Validate once more; if it repeats, keep the key and mark it `unverified` |
| `MISSING` | The key was not saved. Capture again |

A skipped service is allowed: drop its key with `bash "/abs/SKILL_DIR/scripts/ask_secret.sh" <VAR> "/abs/STAGING" --unset`, mark it `skipped`, and tell the user which feature it disables (listed in `references/services.md`). Only keys marked `OK` or `unverified` may remain in the staging file.

### Step 5 — Install folder

If Step 1 already ran this step, skip it.

- **Ask.** "Where should OpenMontage go? Default: `~/OpenMontage`". Expand `~` to an absolute path and record it as `INSTALL_DIR`.
- **Classify.** Run `bash "/abs/SKILL_DIR/scripts/preflight.sh" --folder "<INSTALL_DIR>"` (it never calls `git`):
  - `FOLDER EMPTY` with `DISK OK` → use it.
  - `FOLDER EMPTY` with `DISK LOW` → a new install needs 10 GB on that drive: ask the user to free space and classify again, or to pick a folder on another drive. If they decline both, stop.
  - `FOLDER CLONE` → reuse it; Step 7 updates it. With `DISK LOW`, tell the user the update may still run out of space.
  - `FOLDER FOREIGN` → ask for another path. Do not delete or overwrite.

### Step 6 — Toolchain

Follow `references/install.md` § Toolchain in order: Xcode Command Line Tools → Homebrew → one `brew install` of git, uv, ffmpeg and node → Node.js version check. Skip any item whose check already passes. Wherever the user installs something, wait for their confirmation, then re-run `bash "/abs/SKILL_DIR/scripts/preflight.sh" --keep "/abs/STAGING"` (`--keep` stops it from listing the current key file as a leftover; never delete `STAGING` here) and copy its `CLT` and `BREW_PREFIX` lines into the State block; continue only when the item shows as present (`CLT yes`, or a `BREW_PREFIX` path), otherwise ask the user to finish the install.

Check before moving on (Node.js requirement: `references/install.md` § Toolchain, **Node.js version**):

```bash
eval "$(<BREW_PREFIX>/bin/brew shellenv)"; git --version && uv --version && ffmpeg -version | head -1 && node --version
```

### Step 7 — OpenMontage and dependencies

- **Clone.** Clone or update, then create or reuse the virtual environment, exactly as in `references/install.md` § OpenMontage, including its Python version rule and its guard for local edits. Both ask the user first. Declined local-edit discard → keep the clone and continue. Declined venv recreate → the run ends here: `rm -f "/abs/STAGING"`, skip Steps 8–10 and send the Step 11 report with that open issue.
- **Dependencies.** Launch **two sub-agents in parallel**, one per brief in `references/install.md` § Sub-agent briefs: **Python stack** and **Node stack**. Fill in `<INSTALL_DIR>` and `<BREW_PREFIX>` before sending. If no sub-agent tool exists, run both briefs yourself, one after the other.
- **Reports.** Each brief returns `STATUS: OK` or `STATUS: FAILED` with the failing command and the last error lines. On `FAILED`, apply `references/troubleshooting.md` § Dependencies and re-run only the failed brief — at most two re-runs per brief, the last fallback being `references/install.md` § Version pin fallback. If it still fails, mark the step as an open issue and continue to Step 8. A `NOTES` value other than `none` goes under Open issues in the report.

### Step 8 — Configure .env and WhisperX

```bash
cd "/abs/INSTALL_DIR" && .venv/bin/python "/abs/SKILL_DIR/scripts/write_env.py" "/abs/INSTALL_DIR/.env" "/abs/STAGING"
cd "/abs/INSTALL_DIR" && .venv/bin/python "/abs/SKILL_DIR/scripts/install_compat.py"
```

- `write_env.py` prints one `SET: <VAR>` per collected key. On `ERROR: neither … exists` or `.venv/bin/python: No such file or directory`, the clone or its venv is incomplete: repeat Step 7 **Clone**, then this step. On `ERROR: staging file not found`, the collected keys are lost: run Step 1 **Staging file**, capture the keys again (Steps 2–4), then this step. Remove the staging file only after `SET` lines appear: `rm -f "/abs/STAGING"`.
- If every service was skipped, the staging file is empty: run `write_env.py` anyway (it creates `.env` from `.env.example` with mode 600), then remove the staging file.
- `install_compat.py` puts a small compatibility layer into `.venv` instead of editing OpenMontage: OpenMontage calls `whisperx.DiarizationPipeline(use_auth_token=…)`, which WhisperX 3.8+ no longer provides, and the failure is swallowed silently. It prints `INSTALLED: …` or `OK: …`. `SKIP` or `FAIL` means diarization will not work: note it for the report and continue.

### Step 9 — Verify

1. Run `bash "/abs/SKILL_DIR/scripts/verify.sh" "/abs/INSTALL_DIR" <BREW_PREFIX>` (tool timeout 10 minutes). Each check line starts with `PASS`, `WARN`, `FAIL` or `INFO`; the last line is `TOTAL fail=<n> warn=<n>`. `INFO` marks an optional local extra that is not set up; it is never a problem.
2. For each `FAIL`, apply `references/troubleshooting.md` § Verification and run `verify.sh` again — at most two rounds. What still fails goes into the report as open. Exception: a `FAIL key <VAR>` for a service the State block marks `unverified` is the user's earlier choice. Do not fix or ask again; list it under Open issues.

### Step 10 — Local extras (optional)

Offer only when the last `verify.sh` run has no `FAIL` lines other than `FAIL key` for `unverified` services; otherwise mark this step skipped and say in the report that extras can be added later (§ Add local extras later).

Send the offer from `references/extras.md` § The offer once, as a single message. On two "no" answers, mark the step skipped by the user. Otherwise follow `references/extras.md` § Install, § Docker and § Doctor for what the user accepted. A failed item goes under Open issues; the next item still runs.

- **Docker limit.** At most three `docker info` probes after `open -a Docker`, each with a 20-second limit and each after the user confirms Docker Desktop finished starting. Still not running → list "Docker not running (optional, isolated rendering only)" under Open issues and move on.
- **Doctor.** Keep every `DOCTOR` line (the ✓/✗ checks) for the report; label a ✗ for something the user declined "not set up (declined)". Act on the `RESULT` line:

| Result | Action |
|---|---|
| `RESULT OK` | Done |
| `RESULT FAIL …` with `REASON … not resolvable: timeout (5s)` | Flaky npm lookup: `references/troubleshooting.md` § Local extras, `runtime_available=False` row |
| `RESULT FAIL …` (other) | Apply `references/troubleshooting.md` § Local extras; list what remains under Open issues |
| `RESULT TIMEOUT 300 s` | Run once more; if it repeats, list "hyperframes doctor did not finish" under Open issues |
| `RESULT NO_TARGET` or `RESULT ERROR …` | OpenMontage changed or removed the target: list it under Open issues |

A `DOCTOR` line announcing a newer HyperFrames is checked against npm first (`references/troubleshooting.md` § Local extras, "newer HyperFrames" row); it is often not an issue.

### Step 11 — Report

1. If Step 10 installed or started anything, run `verify.sh` again as in Step 9 item 1: pip installs can move shared packages, and the report must show the final state.
2. Confirm the staging file is gone (`ls "/abs/STAGING"` fails), then send the final report:

```text
OpenMontage is installed in <INSTALL_DIR>

Installed:
- <tool> <version>        (one line per PASS line from verify.sh)

Services:
- Hugging Face — <OK / unverified / skipped: feature disabled>
- Pixabay — ...
- ElevenLabs — ...

Local extras:
- <each DOCTOR line from Step 10, or "declined" / "not offered: fix the open issues first">

Open issues:
- <each remaining FAIL/WARN with the one action that fixes it, or "none">

Start working:
  open a new Claude session in <INSTALL_DIR> (Claude Code: cd <INSTALL_DIR> && claude),
  then describe the video and give the path to your footage.
```

## Add or replace a key later

For "add keys to OpenMontage", or after a skipped or `INVALID` service. This flow uses its own checklist instead of the full one; the completion gate applies to it.

```text
Add keys to OpenMontage:
- [ ] A. Preflight, install check, State
- [ ] B. Keys for: <services>
- [ ] C. Write .env
- [ ] D. Verify and report
```

- **A.** Run Step 1 **Probe**, **Leftover keys**, **Status**, **Staging file** and **State block**. Ask for the existing install and run Step 5 **Classify** on it, ignoring the `DISK` line. Continue only on `FOLDER CLONE` with a `VENV Python 3.…` line; otherwise remove the staging file and offer the full install instead.
- **B.** Run Steps 2–4 for the affected services only.
- **C.** Run the `write_env.py` command from Step 8, then remove the staging file.
- **D.** Run Step 9, then Step 11 (no extras offer in this flow).

## Add local extras later

For "add local extras to OpenMontage" or "fix hyperframes doctor in OpenMontage" on an existing install. Uses its own checklist; the completion gate applies to it. No key is collected, so no staging file is created.

```text
Add local extras to OpenMontage:
- [ ] A. Preflight and install check
- [ ] B. Local extras
- [ ] C. Verify and report
```

- **A.** Run Step 1 **Probe**, **Leftover keys**, **Status** and **State block** (`STAGING: none`). Ask for the existing install and run Step 5 **Classify** on it, ignoring the `DISK` line. Continue only on `FOLDER CLONE` with a `VENV Python 3.…` line; otherwise offer the full install instead.
- **B.** Run Step 10, skipping its `fail=0` condition: the user asked for the extras.
- **C.** Run Step 9, then Step 11 item 2 (Step 9 already ran after the extras, so item 1 is not needed), leaving out the staging-file check and the Services block.

## Troubleshooting

Failures by phase and their fixes are in `references/troubleshooting.md`. If a failure is not listed, show the user the failing command with its last 20 output lines, propose one fix, and wait for approval before changing anything outside `INSTALL_DIR`.
