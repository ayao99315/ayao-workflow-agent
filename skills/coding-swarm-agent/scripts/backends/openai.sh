#!/bin/bash
# openai.sh — OpenAI image generation backend

call_backend() {
  local prompt="$1"
  local output="$2"
  local style="${3:-}"
  local api_key="${OPENAI_API_KEY:-}"
  local model="${OPENAI_IMAGE_MODEL:-dall-e-3}"
  local full_prompt="$prompt"
  local payload=""
  local response=""
  local url=""

  if [[ -z "$api_key" ]]; then
    echo "⚠️  OPENAI_API_KEY not set" >&2
    return 1
  fi

  if [[ -n "$style" ]]; then
    full_prompt="${prompt}. Style: ${style}"
  fi

  payload="$(python3 - "$model" "$full_prompt" <<'PYEOF'
import json
import sys

print(json.dumps({
    "model": sys.argv[1],
    "prompt": sys.argv[2],
    "n": 1,
    "size": "1024x1024",
}))
PYEOF
)" || return 1

  response="$(curl -fsS -X POST "https://api.openai.com/v1/images/generations" \
    -H "Authorization: Bearer ${api_key}" \
    -H "Content-Type: application/json" \
    -d "$payload")" || return 1

  url="$(RESPONSE_JSON="$response" python3 - <<'PYEOF'
import json
import os
import sys

try:
    data = json.loads(os.environ["RESPONSE_JSON"])
    print(data["data"][0]["url"])
except Exception as exc:
    print(f"Failed to parse OpenAI image response: {exc}", file=sys.stderr)
    raise SystemExit(1)
PYEOF
)" || return 1

  curl -fsS -o "$output" "$url" || return 1
}
