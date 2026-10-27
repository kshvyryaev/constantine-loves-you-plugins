#!/usr/bin/env bash
# Validate one API key against its service without printing it.
# The key is passed to curl through a config on stdin, never on the command line.
# Usage: check_key.sh VAR FILE   (FILE holds KEY=value lines: the staging file or .env)
# Output: "VAR: OK | INVALID | NOT_ACCEPTED | NO_PERMISSION | UNREACHABLE | MISSING | UNEXPECTED_HTTP_<code>"
# Exit code 0 only for OK.
set -uo pipefail

var="${1:?VAR required}"
file="${2:?FILE required}"
value=$(grep -m1 -E "^[[:space:]]*(export[[:space:]]+)?${var}=" "$file" 2>/dev/null | cut -d= -f2-)
value="${value%%[[:space:]]#*}"
value=$(printf '%s' "$value" | tr -d '[:space:]')
value="${value#\"}"; value="${value%\"}"; value="${value#\'}"; value="${value%\'}"
[[ -n "$value" ]] || { echo "$var: MISSING"; exit 1; }

body=$(mktemp)
trap 'rm -f "$body"' EXIT

# request <curl config lines...>: prints the HTTP status, response body goes to $body.
request() {
  printf '%s\n' "$@" | /usr/bin/curl -s -m 20 -o "$body" -w '%{http_code}' -K -
}

classify() {
  case "$1" in
    200) echo OK ;;
    000|5??) echo UNREACHABLE ;;
    400|401|403) echo INVALID ;;
    *) echo "UNEXPECTED_HTTP_$1" ;;
  esac
}

case "$var" in
  HF_TOKEN)
    result=$(classify "$(request 'url = "https://huggingface.co/api/whoami-v2"' "header = \"Authorization: Bearer $value\"")")
    if [[ "$result" == OK ]]; then
      gated=$(request 'url = "https://huggingface.co/pyannote/speaker-diarization-community-1/resolve/main/config.yaml"' \
        'head' 'location' "header = \"Authorization: Bearer $value\"")
      case "$gated" in
        200) result=OK ;;
        401|403) result=NOT_ACCEPTED ;;
        *) result=$(classify "$gated") ;;
      esac
    fi
    ;;
  PIXABAY_API_KEY)
    result=$(classify "$(request "url = \"https://pixabay.com/api/?key=${value}&q=test&per_page=3\"")")
    ;;
  ELEVENLABS_API_KEY)
    code=$(request 'url = "https://api.elevenlabs.io/v1/user"' "header = \"xi-api-key: $value\"")
    if [[ "$code" == 401 ]] && grep -q missing_permissions "$body"; then
      result=NO_PERMISSION
    else
      result=$(classify "$code")
    fi
    ;;
  *)
    echo "$var: UNKNOWN_VAR"; exit 1
    ;;
esac

echo "$var: $result"
[[ "$result" == OK ]]
