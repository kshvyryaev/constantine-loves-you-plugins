#!/usr/bin/env bash
# Decide whether this Mac can run the setup, and classify an install folder.
# Usage:
#   preflight.sh                 system check
#   preflight.sh --folder PATH   classify PATH for Step 6
# System output lines: "STATUS OK|STOP <reason>", "BREW_PREFIX <path|not installed>",
#   "CLT yes|no", "TOOL <name> <path>", "STALE_STAGING <path>" (one per leftover key file).
# Folder output: "FOLDER EMPTY|CLONE|FOREIGN <path>" plus "VENV <python version|none>" for a clone.
set -uo pipefail

if [[ "${1:-}" == "--folder" ]]; then
  dir="${2:?PATH required}"
  dir="${dir/#\~/$HOME}"
  if [[ ! -e "$dir" ]] || [[ -z "$(ls -A "$dir" 2>/dev/null)" ]]; then
    echo "FOLDER EMPTY $dir"
  elif grep -qs 'calesthio/OpenMontage' "$dir/.git/config"; then
    echo "FOLDER CLONE $dir"
    if [[ -x "$dir/.venv/bin/python" ]]; then
      echo "VENV $("$dir/.venv/bin/python" --version 2>&1)"
    else
      echo "VENV none"
    fi
  else
    echo "FOLDER FOREIGN $dir"
  fi
  exit 0
fi

reason=""
if [[ "$(uname -s)" != Darwin ]]; then
  reason="not macOS ($(uname -s))"
elif (( $(sw_vers -productVersion | cut -d. -f1) < 13 )); then
  reason="macOS $(sw_vers -productVersion) is older than 13"
else
  free_kb=$(df -k "$HOME" | awk 'NR==2 {print $4}')
  (( free_kb < 10 * 1024 * 1024 )) && reason="only $((free_kb / 1024 / 1024)) GB free, need 10 GB"
fi
if [[ -n "$reason" ]]; then echo "STATUS STOP $reason"; else echo "STATUS OK"; fi

if [[ "$(uname -m)" == arm64 ]]; then prefix=/opt/homebrew; else prefix=/usr/local; fi
if [[ -x "$prefix/bin/brew" ]]; then echo "BREW_PREFIX $prefix"; else echo "BREW_PREFIX not installed"; fi

if xcode-select -p >/dev/null 2>&1; then echo "CLT yes"; else echo "CLT no"; fi

for t in git uv ffmpeg node; do
  [[ -x "$prefix/bin/$t" ]] && echo "TOOL $t $prefix/bin/$t"
done
xcode-select -p >/dev/null 2>&1 && [[ ! -x "$prefix/bin/git" ]] && echo "TOOL git /usr/bin/git"

for f in "${TMPDIR:-/tmp}"/open-montage-keys.*; do
  [[ -e "$f" ]] && echo "STALE_STAGING $f"
done
exit 0
