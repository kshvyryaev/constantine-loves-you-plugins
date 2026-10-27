"""Install or check the WhisperX compatibility layer in OpenMontage's virtual environment.

Usage: <INSTALL_DIR>/.venv/Scripts/python.exe install_compat.py [--check]
Copies openmontage_whisperx_compat.py into the venv's site-packages and adds a .pth file that
imports it at interpreter start, so OpenMontage's own code stays untouched and `git pull` stays clean.
An outdated copy from an earlier skill version is replaced. Then, in a fresh isolated interpreter
(so the installed .pth runs, not the copy next to this script), confirms that the call OpenMontage
makes resolves to a pipeline accepting the token.
Prints "INSTALLED: ...", "OK: ...", "SKIP: ..." or "FAIL: ..." (exit 1).
"""

import shutil
import subprocess
import sys
import sysconfig
from pathlib import Path

MODULE = "openmontage_whisperx_compat"
PTH = "openmontage_whisperx_compat.pth"

CHECK = """
import inspect
try:
    import whisperx
except ImportError as exc:
    print(f"SKIP: whisperx not importable ({exc})")
    raise SystemExit
if not hasattr(whisperx, "DiarizationPipeline"):
    print("FAIL: whisperx.DiarizationPipeline still missing")
    raise SystemExit
from whisperx.diarize import DiarizationPipeline as Pipeline
params = inspect.signature(Pipeline.__init__).parameters
if "token" not in params and "use_auth_token" not in params:
    print("FAIL: WhisperX diarization pipeline takes no token argument")
    raise SystemExit
print("OK")
"""


def target_dir() -> Path:
    return Path(sysconfig.get_paths()["purelib"])


def installed(site: Path) -> bool:
    return (site / f"{MODULE}.py").exists() and (site / PTH).exists()


def current(site: Path, source: Path) -> bool:
    return installed(site) and (site / f"{MODULE}.py").read_bytes() == source.read_bytes()


def works() -> str | None:
    run = subprocess.run([sys.executable, "-I", "-c", CHECK], capture_output=True, text=True)
    verdict = run.stdout.strip().splitlines()
    if verdict and verdict[-1] == "OK":
        return None
    if verdict and verdict[-1].startswith(("SKIP:", "FAIL:")):
        return verdict[-1]
    errors = run.stderr.strip().splitlines()
    return f"FAIL: check crashed: {errors[-1] if errors else f'exit {run.returncode}'}"


def main(check_only: bool) -> int:
    site = target_dir()
    source = Path(__file__).with_name(f"{MODULE}.py")
    if check_only and not installed(site):
        print(f"FAIL: compatibility layer not installed in {site}")
        return 1
    if check_only or current(site, source):
        action = "OK"
    else:
        shutil.copyfile(source, site / f"{MODULE}.py")
        (site / PTH).write_text(f"import {MODULE}\n")
        action = "INSTALLED"

    problem = works()
    if problem:
        print(problem)
        return 0 if problem.startswith("SKIP") else 1
    print(f"{action}: whisperx.DiarizationPipeline available via {site / PTH}")
    return 0


if __name__ == "__main__":
    sys.exit(main("--check" in sys.argv[1:]))
