"""Run OpenMontage's `make hyperframes-doctor` under a time limit and print its findings as plain lines.

Usage: <INSTALL_DIR>/.venv/bin/python hyperframes_doctor.py <INSTALL_DIR> [SECONDS]   (default 300)
The make target runs `hyperframes doctor` through OpenMontage's own Python tool, so .env (including
HYPERFRAMES_PYTHON) is loaded, and prints the result as JSON with escaped symbols. This script decodes it.
Output:
  DOCTOR <line>    one per non-empty line of `hyperframes doctor` output (the ✓/✗ checks)
  REASON <text>    one per reason OpenMontage gives for an unavailable runtime
  NPM <version | error: text>
  RESULT OK | FAIL <error> | TIMEOUT <n> s | NO_TARGET | ERROR <text>
Exit code 0 only for RESULT OK. Never prints .env contents.
"""

from __future__ import annotations

import json
import os
import re
import signal
import subprocess
import sys
from pathlib import Path

ANSI = re.compile(r"\x1b\[[0-9;?]*[A-Za-z]")


def run(install_dir: Path, seconds: int) -> tuple[int | None, str, str]:
    proc = subprocess.Popen(
        ["make", "-s", "hyperframes-doctor"],
        cwd=install_dir,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        start_new_session=True,
    )
    try:
        out, err = proc.communicate(timeout=seconds)
    except subprocess.TimeoutExpired:
        os.killpg(proc.pid, signal.SIGKILL)
        proc.communicate()
        return None, "", ""
    return proc.returncode, out, err


def report(out: str) -> str:
    lines = out.splitlines()
    start = next((i for i, line in enumerate(lines) if line.startswith("{")), None)
    end = max((i for i, line in enumerate(lines) if line.startswith("}")), default=None)
    if start is None or end is None:
        return "ERROR no JSON in make output"
    data = json.loads("\n".join(lines[start : end + 1]))
    doctor = data.get("cli_doctor") or {}
    text = doctor.get("stdout_tail") or doctor.get("stderr_tail") or ""
    for line in ANSI.sub("", text).splitlines():
        if line.strip():
            print(f"DOCTOR {line.strip()}")
    check = data.get("runtime_check") or {}
    for reason in check.get("reasons") or []:
        print(f"REASON {reason}")
    npm = check.get("npm_package_version") or check.get("npm_resolve_error")
    if npm:
        print(f"NPM {npm}" if check.get("npm_package_version") else f"NPM error: {npm}")
    verdict = next((line for line in reversed(lines[end + 1 :]) if line.strip()), "")
    return "OK" if verdict.strip() == "OK" else verdict.replace("FAIL:", "FAIL", 1).strip() or "FAIL no verdict"


def main(argv: list[str]) -> int:
    if not argv:
        sys.exit("usage: hyperframes_doctor.py <INSTALL_DIR> [SECONDS]")
    install_dir = Path(argv[0]).expanduser()
    seconds = int(argv[1]) if len(argv) > 1 else 300
    if not (install_dir / "Makefile").is_file():
        print(f"RESULT ERROR no Makefile in {install_dir}")
        return 1
    code, out, err = run(install_dir, seconds)
    if code is None:
        print(f"RESULT TIMEOUT {seconds} s")
        return 1
    if "No rule to make target" in err:
        print("RESULT NO_TARGET")
        return 1
    try:
        result = report(out)
    except json.JSONDecodeError as exc:
        result = f"ERROR unreadable doctor JSON ({exc.msg})"
    if result.startswith("ERROR"):
        tail = [line for line in err.splitlines() if line.strip()][-1:]
        result += f": {tail[0]}" if tail else f" (make exit {code})"
    print(f"RESULT {result}")
    return 0 if result == "OK" else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
