#!/bin/bash
# nano-banana.sh — Gemini Imagen backend

call_backend() {
  local prompt="$1"
  local output="$2"
  local style="${3:-}"
  local api_key="${GEMINI_API_KEY:-}"
  local swarm_config=""
  local full_prompt="$prompt"
  local payload=""
  local response=""

  if [[ -z "$api_key" ]]; then
    if command -v swarm-config.sh >/dev/null 2>&1; then
      swarm_config="$(command -v swarm-config.sh)"
    else
      local backend_dir
      backend_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
      if [[ -x "$backend_dir/../swarm-config.sh" ]]; then
        swarm_config="$backend_dir/../swarm-config.sh"
      fi
    fi
  fi

  if [[ -z "$api_key" && -n "$swarm_config" ]]; then
    api_key="$("$swarm_config" resolve image_generation.backends.nano-banana.api_key 2>/dev/null || true)"
  fi

  if [[ -z "$api_key" ]]; then
    echo "⚠️  GEMINI_API_KEY not set" >&2
    return 1
  fi

  if [[ -n "$style" ]]; then
    full_prompt="${prompt}. Style: ${style}"
  fi

  payload="$(python3 - "$full_prompt" <<'PYEOF'
import json
import sys

print(json.dumps({
    "instances": [{"prompt": sys.argv[1]}],
    "parameters": {"sampleCount": 1},
}))
PYEOF
)" || return 1

  response="$(curl -fsS -X POST \
    "https://generativelanguage.googleapis.com/v1beta/models/imagen-3.0-generate-001:predict?key=${api_key}" \
    -H "Content-Type: application/json" \
    -d "$payload")" || return 1

  RESPONSE_JSON="$response" python3 - "$output" <<'PYEOF'
import base64
import json
import os
import sys

output_path = sys.argv[1]

try:
    data = json.loads(os.environ["RESPONSE_JSON"])
    img_b64 = data["predictions"][0]["bytesBase64Encoded"]
except Exception as exc:
    print(f"Failed to parse Gemini image response: {exc}", file=sys.stderr)
    raise SystemExit(1)

with open(output_path, "wb") as f:
    f.write(base64.b64decode(img_b64))
PYEOF
}
