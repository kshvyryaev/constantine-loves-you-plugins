"""Merge KEY=value pairs into OpenMontage's .env on Windows without printing values.

Usage:
  write_env.py <INSTALL_DIR>/.env <STAGING_FILE>      keys collected through ask_secret.ps1
  write_env.py <INSTALL_DIR>/.env --set VAR=VALUE     one non-secret setting, e.g. HYPERFRAMES_PYTHON
Creates .env from .env.example when missing, replaces existing KEY= or export KEY= lines and appends new keys.
Running it again with the same input leaves .env unchanged. Before anything is written, the file's access
list is reduced to the current user (icacls), the Windows counterpart of mode 600. Files are read and
written as UTF-8 with LF line endings. Prints one "SET: KEY" line per key.
"""

import re
import subprocess
import sys
from pathlib import Path

SECRET = re.compile(r"KEY|TOKEN|SECRET|PASSWORD")


def current_sid() -> str:
    out = subprocess.run(
        ["whoami", "/user", "/fo", "csv", "/nh"], capture_output=True, encoding="oem", errors="replace", check=True
    ).stdout
    return out.strip().split(",")[-1].strip('"')


def restrict(path: Path) -> None:
    subprocess.run(["icacls", str(path), "/reset"], capture_output=True)
    run = subprocess.run(
        ["icacls", str(path), "/inheritance:r", "/grant:r", f"*{current_sid()}:F"], capture_output=True
    )
    if run.returncode:
        sys.exit(f"ERROR: could not restrict {path} to the current user (icacls exit {run.returncode})")


def read_lines(path: Path) -> list[str]:
    return path.read_text(encoding="utf-8-sig").splitlines()


def read_pairs(staging: Path) -> dict[str, str]:
    pairs = {}
    for line in read_lines(staging):
        if "=" in line:
            key, value = line.split("=", 1)
            pairs[key.strip()] = value.strip()
    return pairs


def parse_setting(arg: str) -> dict[str, str]:
    key, sep, value = arg.partition("=")
    key, value = key.strip(), value.strip()
    if not sep or not re.fullmatch(r"[A-Z_][A-Z0-9_]*", key) or not value:
        sys.exit("ERROR: --set needs VAR=VALUE")
    if SECRET.search(key):
        sys.exit(f"ERROR: {key} looks like a secret; keys go through the staging file")
    if re.search(r"\s|#", value):
        value = f'"{value}"'
    return {key: value}


def write_private(path: Path, text: str) -> None:
    if not path.exists():
        path.open("x").close()
    restrict(path)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


def merge(env_path: Path, pairs: dict[str, str]) -> None:
    if env_path.exists():
        restrict(env_path)
        lines = read_lines(env_path)
    else:
        example = env_path.with_name(".env.example")
        if not example.exists():
            sys.exit(f"ERROR: neither {env_path} nor {example} exists")
        lines = read_lines(example)

    written = set()
    for i, line in enumerate(lines):
        if line.lstrip().startswith("#") or "=" not in line:
            continue
        key = re.sub(r"^export\s+", "", line.split("=", 1)[0].strip())
        if key in pairs:
            lines[i] = f"{key}={pairs[key]}"
            written.add(key)
    lines += [f"{key}={value}" for key, value in pairs.items() if key not in written]

    write_private(env_path, "\n".join(lines) + "\n")
    for key in pairs:
        print(f"SET: {key}")


def main(argv: list[str]) -> None:
    if len(argv) == 3 and argv[1] == "--set":
        merge(Path(argv[0]).expanduser(), parse_setting(argv[2]))
    elif len(argv) == 2:
        staging = Path(argv[1]).expanduser()
        if not staging.is_file():
            sys.exit(f"ERROR: staging file not found: {staging}")
        merge(Path(argv[0]).expanduser(), read_pairs(staging))
    else:
        sys.exit("usage: write_env.py <path/to/.env> <staging-file> | <path/to/.env> --set VAR=VALUE")


if __name__ == "__main__":
    main(sys.argv[1:])
