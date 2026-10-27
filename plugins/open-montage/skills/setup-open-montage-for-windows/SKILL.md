---
name: setup-open-montage-for-windows
description: >
  Guided Windows 10/11 install of OpenMontage, the agentic video studio: Hugging Face, Pixabay and
  ElevenLabs sign-ups one at a time, API keys kept out of chat, toolchain through winget, verified end
  to end. Also adds or replaces keys in an existing Windows install and adds optional local HyperFrames
  extras. Use on Windows when user says "install OpenMontage", "set up OpenMontage", "configure
  OpenMontage", "reinstall OpenMontage", "install OpenMontage on Windows", "add keys to OpenMontage",
  "add local extras to OpenMontage", "fix hyperframes doctor in OpenMontage", "установи OpenMontage",
  "установи OpenMontage на Windows", "настрой OpenMontage", "добавь ключи в OpenMontage", "поставь
  локальные дополнения OpenMontage". Don't use when: user is on macOS (use setup-open-montage-for-mac) or
  Linux, wants to produce a video with an existing install (no skill: start Claude inside the
  OpenMontage folder), or asks to uninstall OpenMontage (no skill covers it; tell the user).
metadata:
  version: 1.4.0
  author: kshvyryaev
---

# Setup OpenMontage on Windows

Guide the user from a fresh Windows PC to a verified OpenMontage install with every agreed service configured. The user does the sign-ups; you do everything else. This flow is a port of the verified macOS skill and has not yet been run end to end on real Windows: when a step behaves differently from this file, fix it through `references/troubleshooting.md` and name the difference in the report.

## File map

| File | Read when |
|---|---|
| `references/services.md` | Steps 2–4: sign-up steps, key settings, what each key enables |
| `references/install.md` | Steps 6–7: winget toolchain, Python version rule, the two sub-agent briefs |
| `references/extras.md` | Step 10: the extras offer, whisper.cpp download, Docker start, doctor results |
| `references/troubleshooting.md` | A command fails, or a result is not covered by the tables in this file |
| `scripts/common.ps1` | Never run it directly: the other `.ps1` scripts load it |
| `scripts/preflight.ps1` | Steps 1 and 5: system check, leftover key files, install-folder classification |
| `scripts/new_staging.ps1` | Step 1: create the private key file |
| `scripts/ask_secret.ps1` | Steps 2–4: capture a key into the staging file without showing it |
| `scripts/check_key.ps1` | Steps 2–4: validate one key against its service |
| `scripts/install_tools.ps1` | Step 6: install Git, uv, FFmpeg, Node.js and the Visual C++ runtime with winget |
| `scripts/write_env.py` | Steps 8 and 10: merge staged keys, or one non-secret setting, into `.env` |
| `scripts/install_compat.py` | Steps 8–9: install or check the WhisperX compatibility layer in `.venv` |
| `scripts/openmontage_whisperx_compat.py` | Never read it into context: `install_compat.py` copies it into `.venv` |
| `scripts/verify.ps1` | Steps 9 and 11: full install check, extras included |
| `scripts/install_whisper.ps1`, `scripts/docker_probe.ps1`, `scripts/hyperframes_doctor.py` | Step 10: whisper.cpp download, Docker probe and start, HyperFrames doctor with a time limit |

## Preconditions

- Windows 10 1809 or newer, or Windows 11, 64-bit; at least 10 GB free on the install folder's drive for a new install (`preflight.ps1` checks both; adding keys needs no free space).
- Internet access, and winget (App Installer); Step 6 covers a PC without it.
- The user can approve UAC prompts: Git, Node.js and the Visual C++ runtime install machine-wide.
- An interactive desktop session for the hidden key dialog. Over SSH or in a headless client, every key must come from a file (`-FromFile`).
- A shell tool (PowerShell, or Bash such as Git Bash in Claude Code). Without one, stop and tell the user the skill cannot run here.
- x64 is the target platform; Step 1 **Status** covers ARM64.

## Critical rules

1. **Keys never pass through chat.** Never ask the user to paste a key into the conversation, and never print, echo, `Get-Content`, `type` or log a key. Keys enter only through `ask_secret.ps1` (hidden Windows dialog, or a file the user names). If the user pastes a key into chat anyway, do not reuse it: tell them to revoke it and create a new one.
2. **No key file outlives the session.** Whenever the workflow stops — finished, aborted, or the user quits midway — remove the staging file and say in your last message that it was removed. Key files left by an earlier interrupted session are removed in Step 1. Remove a file with `Remove-Item -LiteralPath "<path>" -Force`.
3. **Windows PowerShell 5.1 syntax.** Every command here is PowerShell: join commands with `;`, never `&&` or `||`. Scripts always run as `powershell -NoProfile -ExecutionPolicy Bypass -File "<script>" <args>`, which works from a PowerShell and from a Bash shell tool. Inline commands run as written in a PowerShell tool; from a Bash tool wrap them as `powershell -NoProfile -ExecutionPolicy Bypass -Command '<command>'` — inline commands use only double quotes, so the single-quoted wrap is safe. Call `npm.cmd` and `npx.cmd`, never `npm` or `npx`.
4. **Reload PATH in inline commands.** Tools winget installs during the session are not on the PATH the client started with. Start every inline command that calls `git`, `uv`, `node`, `npm.cmd`, `npx.cmd` or `ffmpeg` with the PATH line (the scripts do this themselves):
   ```powershell
   $env:Path=[Environment]::GetEnvironmentVariable("Path","Machine")+";"+[Environment]::GetEnvironmentVariable("Path","User");
   ```
5. **Use literal paths.** Every tool call may start a fresh shell, so variables do not carry over. Write the absolute values of `SKILL_DIR`, `STAGING` and `INSTALL_DIR` from the State block into every command, with backslashes, in double quotes — paths may contain spaces. `SKILL_DIR` is the directory containing this `SKILL.md`.
6. **One service at a time.** Finish a service (key saved and checked, or explicitly skipped) before introducing the next.
7. **Admin installs need the user's approval.** Before `install_tools.ps1` runs, tell the user which UAC prompts to expect (`references/install.md` § Toolchain). Anything that needs an administrator PowerShell (long paths, `winget source reset`, `wsl --install`) is given as an exact command for the user to run; wait until they confirm it finished.
8. **Long commands get a long timeout** (10 minutes or more; 30 for `install_tools.ps1`). `ask_secret.ps1` always runs in the foreground (its dialog waits up to 10 minutes); a tool timeout on it counts as `CANCELLED`. `install_tools.ps1`, `pip install`, `npm.cmd install` and the sub-agent briefs may also run in the background.
9. **Never overwrite foreign data.** An existing install folder is reused only if it is an OpenMontage git clone; any other non-empty folder means asking for a different path. Local edits inside a clone are set aside only with the user's consent.
10. **No success without evidence.** The final report comes only from `verify.ps1` output, plus the `hyperframes_doctor.py` lines for local extras.
11. **Speak the user's language.** Commands, file names and env var names stay as they are.

## Progress checklist

Post this after Step 1 and repost it, updated, at every step boundary. The State block is the session memory: keep it current.

```text
OpenMontage setup (Windows):
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
- ARCH: <x64 | arm64>
- Services: HF=<pending|OK|unverified|skipped> Pixabay=<…> ElevenLabs=<…>
```

**Completion gate:** do not send the final report while any checklist item is neither done, explicitly skipped by the user, nor listed under Open issues in the report.

## Workflow

### Step 1 — Preflight

- **Probe.** Run `powershell -NoProfile -ExecutionPolicy Bypass -File "<SKILL_DIR>\scripts\preflight.ps1"`. If it fails to start because scripts are blocked, see `references/troubleshooting.md` § Shell.
- **Leftover keys.** Do this before acting on `STATUS`, even on `STOP`. For every `STALE_STAGING <path>` line, tell the user a key file from an interrupted earlier run was found and remove it.
- **Status.** `STATUS STOP <reason>`: tell the user the reason and stop. `ARCH arm64`: before any sign-up, tell the user the install is written for x64 and the Python stack (faster-whisper, WhisperX) will probably fail to install for lack of Windows ARM64 packages; continue only if they agree, otherwise stop. `STATUS LOW_DISK <reason>`: the user profile's drive is short on space. Tell the user and run Step 5 now, before any sign-up, so a stop never comes after Steps 2–4. The add-key and local-extras flows ignore `LOW_DISK` and `ARCH`.
- **Staging file.** Run `powershell -NoProfile -ExecutionPolicy Bypass -File "<SKILL_DIR>\scripts\new_staging.ps1"` and note the path from its `STAGING <path>` line. It lives in `%LOCALAPPDATA%\open-montage`, readable only by the current user, so a later session finds leftovers. `ERROR`: `references/troubleshooting.md` § Keys.
- **State block.** Fill it, `ARCH` from the probe.
- **Summary.** Tell the user in 2–3 lines what is already installed (`TOOL`, `VCREDIST` and `WINGET` lines), what will be installed, and that the next steps are three short sign-ups.

### Steps 2–4 — Services

Order: Hugging Face → Pixabay → ElevenLabs. For each service, read its section in `references/services.md`, then:

- **Instruct.** Give the user the numbered sign-up and key-creation steps from that section, including the required key settings.
- **Hand-over.** Ask how they will hand over the key: **hidden dialog** (default) or **path to a file** holding either the bare key on one line or a `VAR=value` line (an existing `.env` works).
- **Capture.** Tell the user a small "OpenMontage setup" window will open (it may appear behind other windows; check the taskbar), then:
  ```powershell
  powershell -NoProfile -ExecutionPolicy Bypass -File "<SKILL_DIR>\scripts\ask_secret.ps1" -Var HF_TOKEN -Staging "<STAGING>" -Prompt "Paste your Hugging Face token"
  # or, if the user named a file:
  powershell -NoProfile -ExecutionPolicy Bypass -File "<SKILL_DIR>\scripts\ask_secret.ps1" -Var HF_TOKEN -Staging "<STAGING>" -FromFile "C:\Users\me\Documents\hf-token.txt"
  ```
  Wait for its result line before **Validate**. Expected: `SAVED: <VAR> (<n> chars)`. `CANCELLED`: the dialog was closed, left empty or timed out — ask the user and capture again. `ERROR`: follow `references/troubleshooting.md` § Keys.
- **Validate.** `powershell -NoProfile -ExecutionPolicy Bypass -File "<SKILL_DIR>\scripts\check_key.ps1" <VAR> "<STAGING>"`, then act on the result and update the State block:

| Result | Action |
|---|---|
| `OK` | Service done |
| `INVALID` | The service rejected the key. Capture again; if it repeats, check `references/troubleshooting.md` § Keys; after two failed retries offer to skip |
| `NOT_ACCEPTED` | Hugging Face only: pyannote model terms not accepted. Send the model link from `references/services.md`, wait for confirmation, validate again. If it repeats, check `references/troubleshooting.md` § Keys; after two re-checks offer to skip or keep the key as `unverified` |
| `NO_PERMISSION` | ElevenLabs only: the key lacks a required permission. Show the permission list from `references/services.md` again, wait, validate again. After two re-checks offer to skip or keep the key as `unverified` |
| `UNREACHABLE` | The service could not be reached from this network. Keep the key, mark it `unverified`, move on |
| `UNEXPECTED_HTTP_<code>` | Validate once more; if it repeats, keep the key and mark it `unverified` |
| `MISSING` | The key was not saved. Capture again |

A skipped service is allowed: drop its key with `ask_secret.ps1 -Var <VAR> -Staging "<STAGING>" -Unset` (same `powershell … -File` form), mark it `skipped`, and tell the user which feature it disables (listed in `references/services.md`). Only keys marked `OK` or `unverified` may remain in the staging file.

### Step 5 — Install folder

If Step 1 already ran this step, skip it.

- **Ask.** "Where should OpenMontage go? Default: `%USERPROFILE%\OpenMontage`". Record the absolute path (for example `C:\Users\Anna\OpenMontage`) as `INSTALL_DIR`. A short path on a local NTFS drive is best: Windows limits path length.
- **Classify.** Run `powershell -NoProfile -ExecutionPolicy Bypass -File "<SKILL_DIR>\scripts\preflight.ps1" -Folder "<INSTALL_DIR>"` (it never calls `git`):
  - `FOLDER EMPTY` with `DISK OK` → use it.
  - `FOLDER EMPTY` with `DISK LOW` → a new install needs 10 GB on that drive: ask the user to free space and classify again, or to pick a folder on another drive. If they decline both, stop.
  - `DISK UNKNOWN` → the drive cannot be checked (network or unusual drive): ask for a folder on a local drive.
  - `FOLDER CLONE` → reuse it; Step 7 updates it. With `DISK LOW`, tell the user the update may still run out of space.
  - `FOLDER FOREIGN` → ask for another path. Do not delete or overwrite.

### Step 6 — Toolchain

Follow `references/install.md` § Toolchain: winget check → UAC warning → `install_tools.ps1`. Continue only on `RESULT OK`. On `RESULT INCOMPLETE`, apply `references/troubleshooting.md` § Toolchain for each `FAILED`, `OLD` or `MISSING` line, then re-run the script — at most two re-runs; after a fix the user made themselves, `-CheckOnly` is enough. What still fails is an open issue, and Step 7 cannot start without git, uv and Node.js 22+: then skip to Step 11 (remove the staging file first).

### Step 7 — OpenMontage and dependencies

- **Clone.** Clone or update, then create or reuse the virtual environment, exactly as in `references/install.md` § OpenMontage, including its Python version rule and its guard for local edits. Both ask the user first. Declined local-edit stash → keep the clone, continue, and list "OpenMontage not updated: local edits kept" under Open issues. Declined venv recreate → the run ends here: remove the staging file, skip Steps 8–10 and send the Step 11 report with that open issue.
- **Dependencies.** Launch **two sub-agents in parallel**, one per brief in `references/install.md` § Sub-agent briefs: **Python stack** and **Node stack**. Fill in `<INSTALL_DIR>` before sending. If no sub-agent tool exists, run both briefs yourself, one after the other.
- **Reports.** Each brief returns `STATUS: OK` or `STATUS: FAILED` with the failing command and the last error lines. On `FAILED`, apply `references/troubleshooting.md` § Dependencies and re-run only the failed brief — at most two re-runs per brief, the last fallback being `references/install.md` § Version pin fallback, which asks the user first (declined → the failing brief goes under Open issues). If it still fails, mark the step as an open issue and continue to Step 8. A `NOTES` value other than `none` goes under Open issues in the report.

### Step 8 — Configure .env and WhisperX

```powershell
Set-Location "<INSTALL_DIR>"; .\.venv\Scripts\python.exe "<SKILL_DIR>\scripts\write_env.py" "<INSTALL_DIR>\.env" "<STAGING>"
Set-Location "<INSTALL_DIR>"; .\.venv\Scripts\python.exe "<SKILL_DIR>\scripts\install_compat.py"
```

- `write_env.py` restricts `.env` to the current user (the Windows counterpart of mode 600) and prints one `SET: <VAR>` per collected key. On `ERROR: neither … exists` or a missing `.venv\Scripts\python.exe`, the clone or its venv is incomplete: repeat Step 7 **Clone**, then this step. On `ERROR: staging file not found`, the collected keys are lost: run Step 1 **Staging file**, capture the keys again (Steps 2–4), then this step. Remove the staging file only after `SET` lines appear.
- If every service was skipped, the staging file is empty: run `write_env.py` anyway (it creates `.env` from `.env.example`), then remove the staging file.
- `install_compat.py` puts a small compatibility layer into `.venv` instead of editing OpenMontage: OpenMontage calls `whisperx.DiarizationPipeline(use_auth_token=…)`, which WhisperX 3.8+ no longer provides, and the failure is swallowed silently. It prints `INSTALLED: …` or `OK: …`. `SKIP` or `FAIL` means diarization will not work: note it for the report and continue.

### Step 9 — Verify

1. Run `powershell -NoProfile -ExecutionPolicy Bypass -File "<SKILL_DIR>\scripts\verify.ps1" "<INSTALL_DIR>"` (tool timeout 15 minutes). Each check line starts with `PASS`, `WARN`, `FAIL` or `INFO`; the last line is `TOTAL fail=<n> warn=<n>`. `INFO` marks an optional local extra that is not set up; it is never a problem.
2. For each `FAIL`, apply `references/troubleshooting.md` § Verification and run `verify.ps1` again — at most two rounds. What still fails goes into the report as open. Exception: a `FAIL key <VAR>` for a service the State block marks `unverified` is the user's earlier choice. Do not fix or ask again; list it under Open issues.

### Step 10 — Local extras (optional)

Offer only when the last `verify.ps1` run has no `FAIL` lines other than `FAIL key` for `unverified` services; otherwise mark this step skipped and say in the report that extras can be added later (§ Add local extras later).

Send the offer from `references/extras.md` § The offer once, as a single message. On two "no" answers, mark the step skipped by the user. Otherwise follow `references/extras.md` § Install, § Docker and § Doctor for what the user accepted. A failed item goes under Open issues; the next item still runs.

- **Docker limit.** At most three `docker_probe.ps1` probes after the `-Start` run, each after the user confirms Docker Desktop finished starting. Still `NOT_RUNNING` → list "Docker not running (optional, isolated rendering only)" under Open issues and move on.
- **Doctor.** Its `DOCTOR` lines go into the report; its `RESULT` line is handled by the table in `references/extras.md` § Doctor.

### Step 11 — Report

1. If Step 10 installed or started anything, run `verify.ps1` again as in Step 9 item 1: pip installs can move shared packages, and the report must show the final state.
2. Confirm the staging file is gone (`Test-Path -LiteralPath "<STAGING>"` prints `False`), then send the final report:

```text
OpenMontage is installed in <INSTALL_DIR>

Installed:
- <tool> <version>        (one line per PASS line from verify.ps1)

Services:
- Hugging Face — <OK / unverified / skipped: feature disabled>
- Pixabay — ...
- ElevenLabs — ...

Local extras:
- <each DOCTOR line from Step 10, or "declined" / "not offered: fix the open issues first">

Open issues:
- <each remaining FAIL/WARN with the one action that fixes it, and any step that behaved
  differently from this skill, or "none">

Start working:
  open a new Claude session in <INSTALL_DIR> (Claude Code: cd "<INSTALL_DIR>"; claude),
  then describe the video and give the path to your footage.
```

## Add or replace a key later

For "add keys to OpenMontage", or after a skipped or `INVALID` service. This flow uses its own checklist instead of the full one; the completion gate applies to it.

```text
Add keys to OpenMontage (Windows):
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
Add local extras to OpenMontage (Windows):
- [ ] A. Preflight and install check
- [ ] B. Local extras
- [ ] C. Verify and report
```

- **A.** Run Step 1 **Probe**, **Leftover keys**, **Status** and **State block** (`STAGING: none`). Ask for the existing install and run Step 5 **Classify** on it, ignoring the `DISK` line. Continue only on `FOLDER CLONE` with a `VENV Python 3.…` line; otherwise offer the full install instead.
- **B.** Run Step 10, skipping its `fail=0` condition: the user asked for the extras.
- **C.** Run Step 9, then Step 11 item 2 (Step 9 already ran after the extras, so item 1 is not needed), leaving out the staging-file check and the Services block.

## Troubleshooting

Failures by phase and their fixes are in `references/troubleshooting.md`. If a failure is not listed, show the user the failing command with its last 20 output lines, propose one fix, and wait for approval before changing anything outside `INSTALL_DIR`.
