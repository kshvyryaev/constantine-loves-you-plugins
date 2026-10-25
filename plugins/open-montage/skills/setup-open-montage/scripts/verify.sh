#!/usr/bin/env bash
# Check an OpenMontage install end to end. Never prints key values.
# Usage: verify.sh INSTALL_DIR [BREW_PREFIX]
# BREW_PREFIX defaults to /opt/homebrew on arm64 and /usr/local on x86_64.
# Output: one "PASS|WARN|FAIL <check> <detail>" line per check, then a totals line.
# Exit code 1 if any FAIL.
set -uo pipefail

dir="${1:?INSTALL_DIR required}"
if [[ "$(uname -m)" == arm64 ]]; then brew_prefix="${2:-/opt/homebrew}"; else brew_prefix="${2:-/usr/local}"; fi
dir="${dir/#\~/$HOME}"
here="$(cd "$(dirname "$0")" && pwd)"
py="$dir/.venv/bin/python"
fails=0; warns=0

line() {
  printf '%s %s %s\n' "$1" "$2" "$3"
  [[ "$1" == FAIL ]] && fails=$((fails + 1))
  [[ "$1" == WARN ]] && warns=$((warns + 1))
}

tool() {
  local name="$1"; shift
  local out
  if out=$("$@" 2>&1 | head -1) && [[ -n "$out" ]]; then line PASS "$name" "$out"; else line FAIL "$name" "not found"; fi
}

[[ -x "$brew_prefix/bin/brew" ]] && eval "$("$brew_prefix/bin/brew" shellenv)"

if [[ "$(uname -s)" == Darwin ]] && (( $(sw_vers -productVersion | cut -d. -f1) >= 13 )); then
  line PASS macos "$(sw_vers -productVersion) $(uname -m)"
else
  line FAIL macos "$(uname -s) $(sw_vers -productVersion 2>/dev/null) (need macOS 13+)"
fi
tool homebrew brew --version
if xcode-select -p >/dev/null 2>&1 || [[ -x "$brew_prefix/bin/git" ]]; then
  tool git git --version
else
  line FAIL git "Command Line Tools missing"
fi
tool uv uv --version
tool ffmpeg ffmpeg -version

if node_v=$(node --version 2>/dev/null); then
  major="${node_v#v}"; major="${major%%.*}"
  if (( major >= 22 )); then line PASS node "$node_v"; else line FAIL node "$node_v (need v22+)"; fi
else
  line FAIL node "not found"
fi

if [[ -d "$dir/.git" ]]; then
  line PASS openmontage "$(git -C "$dir" log -1 --format='%h %cd' --date=short)"
else
  line FAIL openmontage "no git clone at $dir"
fi

if py_v=$("$py" --version 2>&1); then
  case "$py_v" in
    "Python 3.1"[0-3]*) line PASS python "$py_v (.venv)" ;;
    *) line FAIL python "$py_v (.venv needs 3.10-3.13)" ;;
  esac
else
  line FAIL python "no .venv in $dir"
fi

for mod in faster_whisper whisperx piper fastapi; do
  if "$py" -c "import $mod" >/dev/null 2>&1; then
    line PASS "import" "$mod"
  else
    line FAIL "import" "$mod"
  fi
done

if av_v=$("$py" -c "import av; print(av.__version__)" 2>/dev/null) && [[ -n "$av_v" ]]; then
  if (( ${av_v%%.*} < 19 )); then line PASS av "$av_v"; else line FAIL av "$av_v (need <19: pip install \"av<19\")"; fi
else
  line FAIL av "not importable"
fi

if [[ -d "$dir/remotion-composer/node_modules" ]]; then line PASS remotion "node_modules installed"; else line FAIL remotion "run npm install in remotion-composer"; fi

if hf_v=$(cd "$dir" && perl -e 'alarm shift; exec @ARGV' 60 npx --yes hyperframes --version 2>/dev/null | grep -Eo '[0-9]+(\.[0-9]+)+' | head -1) && [[ -n "$hf_v" ]]; then
  line PASS hyperframes "$hf_v"
else
  line WARN hyperframes "not available within 60 s; fetched on first render"
fi

env="$dir/.env"
if [[ -f "$env" ]]; then
  perms=$(stat -f '%Lp' "$env")
  if [[ "$perms" == 600 ]]; then line PASS "env permissions" "600"; else line FAIL "env permissions" "$perms (need 600)"; fi
  for var in HF_TOKEN PIXABAY_API_KEY ELEVENLABS_API_KEY; do
    if ! grep -q "^${var}=." "$env"; then
      line WARN env "$var not set"
      continue
    fi
    res=$(bash "$here/check_key.sh" "$var" "$env")
    case "$res" in
      *": OK") line PASS key "$res" ;;
      *": UNREACHABLE") line WARN key "$res" ;;
      *) line FAIL key "$res" ;;
    esac
  done
else
  line FAIL env "no .env in $dir"
fi

diar=""
[[ -x "$py" ]] && diar=$(cd "$dir" && "$py" "$here/install_compat.py" --check 2>&1 | tail -1)
case "$diar" in
  OK:*) line PASS diarization "${diar#OK: }" ;;
  *) line WARN diarization "${diar:-compat check did not run}" ;;
esac

if (cd "$dir" && make -s preflight >/dev/null 2>&1); then line PASS preflight "make preflight ok"; else line FAIL preflight "make preflight failed"; fi

echo "TOTAL fail=$fails warn=$warns"
(( fails == 0 ))
