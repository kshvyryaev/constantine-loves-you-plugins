"""Align OpenMontage's speaker-diarization call with the installed WhisperX. Idempotent.

Usage: <INSTALL_DIR>/.venv/bin/python patch_diarization.py [--check] <INSTALL_DIR>

OpenMontage calls `whisperx.DiarizationPipeline(use_auth_token=...)`. WhisperX 3.8+ exposes the
class only as `whisperx.diarize.DiarizationPipeline` and names the argument `token`. The call sits
inside a broad try/except, so the mismatch silently disables diarization. This script rewrites
only that call, and only when the installed WhisperX needs it, then checks the end state.
--check reports without writing.
Prints "PATCHED: ...", "NEEDS_PATCH: ...", "OK: ...", "SKIP: ..." or "FAIL: ..." (exit 1).
"""

import inspect
import re
import sys
from pathlib import Path

CALL = re.compile(r"^(?P<indent>[ \t]*)diarize_model = whisperx\.DiarizationPipeline\(", re.MULTILINE)


def problems(source: str, has_top_level: bool, params) -> list[str]:
    found = []
    if "DiarizationPipeline(" not in source:
        found.append("diarization call not found")
    if not has_top_level and "whisperx.DiarizationPipeline(" in source:
        found.append("still calls whisperx.DiarizationPipeline")
    if "use_auth_token" not in params and "use_auth_token=" in source:
        found.append("still passes use_auth_token")
    return found


def main(install_dir: Path, check_only: bool) -> int:
    target = install_dir / "tools" / "analysis" / "transcriber.py"
    if not target.exists():
        print(f"FAIL: {target} not found")
        return 1

    try:
        import whisperx
        from whisperx.diarize import DiarizationPipeline
    except ImportError as exc:
        print(f"SKIP: whisperx not importable ({exc})")
        return 0

    has_top_level = hasattr(whisperx, "DiarizationPipeline")
    params = inspect.signature(DiarizationPipeline.__init__).parameters
    source = target.read_text()
    patched = source
    changes = []

    if not has_top_level and CALL.search(patched):
        patched = CALL.sub(
            lambda m: f"{m['indent']}from whisperx.diarize import DiarizationPipeline\n"
            f"{m['indent']}diarize_model = DiarizationPipeline(",
            patched,
        )
        changes.append("whisperx.DiarizationPipeline -> whisperx.diarize.DiarizationPipeline")
    if "token" in params and "use_auth_token" not in params and "use_auth_token=hf_token" in patched:
        patched = patched.replace("use_auth_token=hf_token", "token=hf_token")
        changes.append("use_auth_token -> token")

    remaining = problems(patched, has_top_level, params)
    if remaining:
        print("FAIL: unrecognised diarization call (" + "; ".join(remaining) + ")")
        return 1
    if not changes:
        print("OK: diarization call matches the installed WhisperX")
        return 0
    if check_only:
        print("NEEDS_PATCH: " + "; ".join(changes))
        return 1
    target.write_text(patched)
    print("PATCHED: " + "; ".join(changes))
    return 0


if __name__ == "__main__":
    args = sys.argv[1:]
    check = "--check" in args
    paths = [a for a in args if a != "--check"]
    if len(paths) != 1:
        sys.exit("usage: patch_diarization.py [--check] <INSTALL_DIR>")
    sys.exit(main(Path(paths[0]).expanduser(), check))
