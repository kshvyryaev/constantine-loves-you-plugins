# open-montage

Guided setup of [OpenMontage](https://github.com/calesthio/OpenMontage), the open-source agentic video production studio, on macOS and Windows.

The `setup-open-montage-for-mac` skill takes you from an empty Mac to a verified install:

1. Walks you through three sign-ups, one at a time, and collects each API key through a hidden macOS dialog (or a file you point to). Keys never appear in the chat.
2. Asks where to install (default `~/OpenMontage`).
3. Installs the toolchain: Xcode Command Line Tools, Homebrew, git, uv, Python 3.12, FFmpeg, Node.js 22+.
4. Clones OpenMontage and installs its Python stack (requirements, Piper, faster-whisper, WhisperX) and Node stack (Remotion, HyperFrames) in two parallel sub-agents.
5. Writes the keys into `.env` (mode 600) and adds a small compatibility layer to the virtual environment so OpenMontage's speaker diarization works with current WhisperX, without editing OpenMontage's code.
6. Verifies every tool, import and key.
7. Optionally adds local extras for HyperFrames: whisper.cpp, the Kokoro voice and MusicGen music packages, and a Docker Desktop start. OpenMontage works without them; the Kokoro model (~300 MB) and MusicGen weights (1.5–3 GB) download on first use.
8. Prints what is installed and configured.

## Services

| Service | Env var | Used for | Cost |
|---|---|---|---|
| Hugging Face | `HF_TOKEN` | Speaker diarization (WhisperX + pyannote) | Free |
| Pixabay | `PIXABAY_API_KEY` | Stock video and images | Free |
| ElevenLabs | `ELEVENLABS_API_KEY` | Narration, music, sound effects | Free tier; paid plans for commercial use |

Any service can be skipped; the skill reports which feature that disables.

## Windows

The `setup-open-montage-for-windows` skill runs the same flow on Windows 10 (1809+) and Windows 11:

- Keys go through a hidden Windows dialog (or a file) and never appear in the chat; the key file and `.env` are readable only by your Windows account.
- The toolchain comes from winget: Git, uv, FFmpeg, Node.js LTS and the Visual C++ runtime. Windows asks you to approve Git, Node.js and the Visual C++ runtime (UAC prompts).
- Python 3.12 comes from uv; dependencies, `.env`, the WhisperX compatibility layer and verification work as on macOS. Optional extras download the prebuilt whisper.cpp for Windows.
- Status: ported from the verified macOS flow but **not yet run end to end on a real Windows machine**. If a step differs, the skill fixes it through its troubleshooting guide and lists the difference in the final report.

## Requirements

macOS:

- macOS on Apple Silicon (verified). Intel Macs are not verified: PyTorch no longer publishes Intel macOS wheels, so WhisperX may not install there.
- 10 GB free disk space on the drive you install to
- Your Mac admin password (Homebrew, Xcode Command Line Tools)

Windows:

- Windows 10 1809+ or Windows 11, x64. ARM64 is not supported by the Python stack (no Windows ARM64 packages for faster-whisper).
- winget (App Installer from the Microsoft Store; built into current Windows)
- 10 GB free disk space on the drive you install to
- Permission to approve UAC prompts

## Installation

```shell
/plugin marketplace add https://github.com/kshvyryaev/constantine-loves-you-plugins
/plugin install open-montage@constantine-loves-you-plugins
```

## Usage

```
install OpenMontage
set up OpenMontage
установи OpenMontage
add local extras to OpenMontage
```

Skills: `open-montage:setup-open-montage-for-mac` (macOS), `open-montage:setup-open-montage-for-windows` (Windows)

After setup, start Claude Code inside the install folder (macOS: `cd ~/OpenMontage && claude`; Windows: `cd $env:USERPROFILE\OpenMontage; claude`) and describe the video you want.
