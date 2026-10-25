"""Merge KEY=value pairs from a staging file into OpenMontage's .env without printing values.

Usage: write_env.py <INSTALL_DIR>/.env <STAGING_FILE>
Creates .env from .env.example when missing, replaces existing KEY= or export KEY= lines and appends new keys.
The file is restricted to the current user before any key is written.
Prints one "SET: KEY" line per key.
"""

import os
import re
import sys
from pathlib import Path


def read_pairs(staging: Path) -> dict[str, str]:
    pairs = {}
    for line in staging.read_text().splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            pairs[key.strip()] = value.strip()
    return pairs


def write_private(path: Path, text: str) -> None:
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    os.fchmod(fd, 0o600)
    with os.fdopen(fd, "w") as f:
        f.write(text)


def main(env_path: Path, staging: Path) -> None:
    if not staging.is_file():
        sys.exit(f"ERROR: staging file not found: {staging}")
    if env_path.exists():
        env_path.chmod(0o600)
        lines = env_path.read_text().splitlines()
    else:
        example = env_path.with_name(".env.example")
        if not example.exists():
            sys.exit(f"ERROR: neither {env_path} nor {example} exists")
        lines = example.read_text().splitlines()

    pairs = read_pairs(staging)
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


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit("usage: write_env.py <path/to/.env> <staging-file>")
    main(Path(sys.argv[1]).expanduser(), Path(sys.argv[2]).expanduser())
