#!/usr/bin/env bash
# Capture one API key into a private KEY=value staging file without printing it.
# Usage:
#   ask_secret.sh VAR STAGING_FILE "Dialog prompt"
#   ask_secret.sh VAR STAGING_FILE --from-file PATH
#   ask_secret.sh VAR STAGING_FILE --unset          (drop VAR, e.g. when the user skips the service)
# PATH holds either a "VAR=value" line (e.g. an existing .env; "export", quotes and " # comments" are
# handled) or the bare key on a single line.
# Output: "SAVED: VAR (N chars)" | "UNSET: VAR" | "CANCELLED: ..." (exit 3) | "ERROR: ..." (exit 2).
set -euo pipefail

var="${1:?VAR required}"
staging="${2:?STAGING_FILE required}"
shift 2

unquote() {
  local v="$1"
  v="${v%%[[:space:]]#*}"
  v=$(printf '%s' "$v" | tr -d '[:space:]')
  v="${v#\"}"; v="${v%\"}"; v="${v#\'}"; v="${v%\'}"
  printf '%s' "$v"
}

if [[ "${1:-}" == "--unset" ]]; then
  umask 077
  touch "$staging"
  grep -v "^${var}=" "$staging" > "$staging.tmp" || true
  mv "$staging.tmp" "$staging"
  chmod 600 "$staging"
  echo "UNSET: $var"
  exit 0
fi

if [[ "${1:-}" == "--from-file" ]]; then
  src="${2:?PATH required after --from-file}"
  src="${src/#\~/$HOME}"
  [[ -s "$src" ]] || { echo "ERROR: file not found or empty: $src"; exit 2; }
  line_re="^[[:space:]]*(export[[:space:]]+)?${var}="
  if grep -qE "$line_re" "$src"; then
    value=$(unquote "$(grep -m1 -E "$line_re" "$src" | cut -d= -f2-)")
    [[ -n "$value" ]] || { echo "ERROR: ${var}= line is empty in $src"; exit 2; }
  elif [[ $(grep -c . "$src") -eq 1 ]] && grep -qE '^[[:space:]]*(export[[:space:]]+)?[A-Z_][A-Z0-9_]*=' "$src"; then
    echo "ERROR: $src holds a different VAR= line, not ${var}"; exit 2
  elif [[ $(grep -c . "$src") -eq 1 ]]; then
    value=$(unquote "$(grep -m1 . "$src")")
  else
    echo "ERROR: $src has several lines and no ${var}= line"; exit 2
  fi
else
  prompt="${1:-Paste $var}"
  prompt="${prompt//\"/}"
  err=$(mktemp)
  trap 'rm -f "$err"' EXIT
  if ! value=$(osascript -e "text returned of (display dialog \"$prompt\" default answer \"\" with hidden answer with title \"OpenMontage setup\" giving up after 600)" 2>"$err"); then
    if grep -q -- "-128" "$err"; then
      echo "CANCELLED: dialog closed for $var"; exit 3
    fi
    echo "ERROR: osascript dialog unavailable"; exit 2
  fi
  value=$(unquote "$value")
fi

[[ -n "$value" ]] || { echo "CANCELLED: no value entered for $var"; exit 3; }

umask 077
touch "$staging"
tmp="$staging.tmp"
grep -v "^${var}=" "$staging" > "$tmp" || true
printf '%s=%s\n' "$var" "$value" >> "$tmp"
mv "$tmp" "$staging"
chmod 600 "$staging"
echo "SAVED: $var (${#value} chars)"
