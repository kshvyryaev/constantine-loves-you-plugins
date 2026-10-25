# open-montage

Guided setup of [OpenMontage](https://github.com/calesthio/OpenMontage), the open-source agentic video production studio, on macOS.

The `setup-open-montage` skill takes you from an empty Mac to a verified install:

1. Walks you through three sign-ups, one at a time, and collects each API key through a hidden macOS dialog (or a file you point to). Keys never appear in the chat.
2. Asks where to install (default `~/OpenMontage`).
3. Installs the toolchain: Xcode Command Line Tools, Homebrew, git, uv, Python 3.12, FFmpeg, Node.js 22+.
4. Clones OpenMontage and installs its Python stack (requirements, Piper, faster-whisper, WhisperX) and Node stack (Remotion, HyperFrames) in two parallel sub-agents.
5. Writes the keys into `.env` (mode 600) and adds a small compatibility layer to the virtual environment so OpenMontage's speaker diarization works with current WhisperX, without editing OpenMontage's code.
6. Verifies every tool, import and key, and prints what is installed and configured.

## Services

| Service | Env var | Used for | Cost |
|---|---|---|---|
| Hugging Face | `HF_TOKEN` | Speaker diarization (WhisperX + pyannote) | Free |
| Pixabay | `PIXABAY_API_KEY` | Stock video and images | Free |
| ElevenLabs | `ELEVENLABS_API_KEY` | Narration, music, sound effects | Free tier; paid plans for commercial use |

Any service can be skipped; the skill reports which feature that disables.

## Requirements

- macOS (Apple Silicon or Intel)
- 10 GB free disk space on the drive you install to
- Your Mac admin password (Homebrew, Xcode Command Line Tools)

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
```

Skill: `open-montage:setup-open-montage`

After setup, start Claude Code inside the install folder (`cd ~/OpenMontage && claude`) and describe the video you want.
