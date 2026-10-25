#!/usr/bin/env bash
# Decide whether this Mac can run the setup, and classify an install folder.
# Usage:
#   preflight.sh                 system check
#   preflight.sh --keep STAGING  system check that does not list the current STAGING file as stale
#   preflight.sh --folder PATH   classify PATH for Step 5
# System output lines: "STATUS OK|LOW_DISK <reason>|STOP <reason>", "BREW_PREFIX <path|not installed>",
#   "CLT yes|no", "TOOL <name> <path>", "STALE_STAGING <path>" (one per leftover key file).
# Folder output: "FOLDER EMPTY|CLONE|FOREIGN <path>", "VENV <python version|none>" for a clone, and
#   "DISK OK|LOW <n> GB free" for the drive PATH is on (its nearest existing parent folder).
# A new install needs 10 GB free on the drive of the install folder.
set -uo pipefail

need_gb=10

free_gb() {
  local p="$1"
  while [[ ! -e "$p" ]]; do p=$(dirname "$p"); done
  df -Pk "$p" | awk 'NR==2 {print int($4 / 1024 / 1024)}'
}

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
  gb=$(free_gb "$dir")
  if (( gb < need_gb )); then echo "DISK LOW $gb GB free"; else echo "DISK OK $gb GB free"; fi
  exit 0
fi

keep=""
[[ "${1:-}" == "--keep" ]] && keep="${2:?STAGING required after --keep}"

reason=""; low=""
if [[ "$(uname -s)" != Darwin ]]; then
  reason="not macOS ($(uname -s))"
elif (( $(sw_vers -productVersion | cut -d. -f1) < 13 )); then
  reason="macOS $(sw_vers -productVersion) is older than 13"
else
  gb=$(free_gb "$HOME")
  (( gb < need_gb )) && low="only $gb GB free on the home folder's drive, a new install needs $need_gb GB"
fi
if [[ -n "$reason" ]]; then echo "STATUS STOP $reason"
elif [[ -n "$low" ]]; then echo "STATUS LOW_DISK $low"
else echo "STATUS OK"; fi

if [[ "$(uname -m)" == arm64 ]]; then prefix=/opt/homebrew; else prefix=/usr/local; fi
if [[ -x "$prefix/bin/brew" ]]; then echo "BREW_PREFIX $prefix"; else echo "BREW_PREFIX not installed"; fi

if xcode-select -p >/dev/null 2>&1; then echo "CLT yes"; else echo "CLT no"; fi

for t in git uv ffmpeg node; do
  [[ -x "$prefix/bin/$t" ]] && echo "TOOL $t $prefix/bin/$t"
done
xcode-select -p >/dev/null 2>&1 && [[ ! -x "$prefix/bin/git" ]] && echo "TOOL git /usr/bin/git"

for f in "$HOME/Library/Caches/open-montage"/keys.* "${TMPDIR:-/tmp}"/open-montage-keys.*; do
  [[ -e "$f" && "$f" != "$keep" ]] && echo "STALE_STAGING $f"
done
exit 0
