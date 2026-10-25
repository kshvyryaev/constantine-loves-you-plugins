"""Install or check the WhisperX compatibility layer in OpenMontage's virtual environment.

Usage: <INSTALL_DIR>/.venv/bin/python install_compat.py [--check]
Copies openmontage_whisperx_compat.py into the venv's site-packages and adds a .pth file that
imports it at interpreter start, so OpenMontage's own code stays untouched and `git pull` stays clean.
Then confirms that the call OpenMontage makes resolves to a pipeline accepting the token.
Prints "INSTALLED: ...", "OK: ...", "SKIP: ..." or "FAIL: ..." (exit 1).
"""

import importlib
import inspect
import shutil
import sys
import sysconfig
from pathlib import Path

MODULE = "openmontage_whisperx_compat"
PTH = "openmontage_whisperx_compat.pth"


def target_dir() -> Path:
    return Path(sysconfig.get_paths()["purelib"])


def installed(site: Path) -> bool:
    return (site / f"{MODULE}.py").exists() and (site / PTH).exists()


def works() -> str | None:
    try:
        import whisperx
    except ImportError as exc:
        return f"SKIP: whisperx not importable ({exc})"
    importlib.import_module(MODULE)
    if not hasattr(whisperx, "DiarizationPipeline"):
        return "FAIL: whisperx.DiarizationPipeline still missing"
    from whisperx.diarize import DiarizationPipeline as Pipeline

    params = inspect.signature(Pipeline.__init__).parameters
    if "token" not in params and "use_auth_token" not in params:
        return "FAIL: WhisperX diarization pipeline takes no token argument"
    return None


def main(check_only: bool) -> int:
    site = target_dir()
    if not installed(site):
        if check_only:
            print(f"FAIL: compatibility layer not installed in {site}")
            return 1
        shutil.copyfile(Path(__file__).with_name(f"{MODULE}.py"), site / f"{MODULE}.py")
        (site / PTH).write_text(f"import {MODULE}\n")
        action = "INSTALLED"
    else:
        action = "OK"

    problem = works()
    if problem:
        print(problem)
        return 0 if problem.startswith("SKIP") else 1
    print(f"{action}: whisperx.DiarizationPipeline available via {site / PTH}")
    return 0


if __name__ == "__main__":
    sys.exit(main("--check" in sys.argv[1:]))
