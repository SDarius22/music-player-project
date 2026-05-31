#!/usr/bin/env bash
set -euo pipefail

EMAIL="${1:-}"
API="${2:-http://localhost:9000/api/v1}"

if [[ -z "$EMAIL" ]]; then
  echo "usage: $0 <email> [api_base_url]" >&2
  exit 2
fi

command -v curl >/dev/null || { echo "curl required" >&2; exit 1; }

json_value() {
  local json="$1" key="$2"
  if command -v jq >/dev/null; then
    printf '%s' "$json" | jq -r --arg key "$key" '.[$key] // empty'
  else
    printf '%s' "$json" | sed -n "s/.*\"$key\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p"
  fi
}

echo "[token] requesting login code for $EMAIL"
status=$(curl -fsS -o /dev/null -w '%{http_code}' \
  -X POST "$API/auth/send-code" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"$EMAIL\"}") || true

[[ "$status" == "200" ]] || echo "[token] send-code returned HTTP $status" >&2

read -r -p "[token] code: " CODE
[[ -n "$CODE" ]] || { echo "no code entered" >&2; exit 2; }

response=$(curl -fsS -X POST "$API/auth/verify" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"$EMAIL\",\"code\":\"$CODE\"}") \
  || { echo "[token] verify failed" >&2; exit 1; }

ACCESS="$(json_value "$response" accessToken)"
REFRESH="$(json_value "$response" refreshToken)"

[[ -n "$ACCESS" ]] || { echo "[token] no accessToken in response: $response" >&2; exit 1; }

echo
echo "AUTH_TOKEN=$ACCESS"
echo "REFRESH_TOKEN=$REFRESH"
