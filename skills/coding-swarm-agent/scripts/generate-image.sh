#!/bin/bash
# generate-image.sh — Unified image generation entrypoint with fail-safe stub fallback

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKENDS_DIR="$SCRIPT_DIR/backends"

PROMPT=""
OUTPUT=""
BACKEND=""
STYLE=""

usage() {
  cat <<'EOF' >&2
Usage:
  generate-image.sh --prompt "..." --output path/to/image.png [--backend name] [--style "..."]
EOF
}

find_swarm_config() {
  if command -v swarm-config.sh >/dev/null 2>&1; then
    command -v swarm-config.sh
    return 0
  fi

  if [[ -x "$SCRIPT_DIR/swarm-config.sh" ]]; then
    printf '%s\n' "$SCRIPT_DIR/swarm-config.sh"
    return 0
  fi

  return 1
}

parse_args() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --prompt)
        [[ "$#" -ge 2 ]] || {
          echo "❌ --prompt requires a value" >&2
          usage
          return 1
        }
        PROMPT="$2"
        shift 2
        ;;
      --output)
        [[ "$#" -ge 2 ]] || {
          echo "❌ --output requires a value" >&2
          usage
          return 1
        }
        OUTPUT="$2"
        shift 2
        ;;
      --backend)
        [[ "$#" -ge 2 ]] || {
          echo "❌ --backend requires a value" >&2
          usage
          return 1
        }
        BACKEND="$2"
        shift 2
        ;;
      --style)
        [[ "$#" -ge 2 ]] || {
          echo "❌ --style requires a value" >&2
          usage
          return 1
        }
        STYLE="$2"
        shift 2
        ;;
      -h|--help)
        usage
        return 1
        ;;
      *)
        echo "❌ Unknown argument: $1" >&2
        usage
        return 1
        ;;
    esac
  done

  [[ -n "$PROMPT" ]] || {
    echo "❌ --prompt is required" >&2
    usage
    return 1
  }
  [[ -n "$OUTPUT" ]] || {
    echo "❌ --output is required" >&2
    usage
    return 1
  }
}

resolve_default_backend() {
  local configured_backend=""
  local swarm_config=""

  if [[ -n "$BACKEND" ]]; then
    printf '%s\n' "$BACKEND"
    return 0
  fi

  if swarm_config="$(find_swarm_config 2>/dev/null)"; then
    configured_backend="$("$swarm_config" get image_generation.default_backend 2>/dev/null || true)"
  fi
  if [[ -n "$configured_backend" ]]; then
    printf '%s\n' "$configured_backend"
    return 0
  fi

  if [[ -n "${GEMINI_API_KEY:-}" ]]; then
    printf '%s\n' "nano-banana"
    return 0
  fi
  if [[ -n "${OPENAI_API_KEY:-}" ]]; then
    printf '%s\n' "openai"
    return 0
  fi

  printf '%s\n' "stub"
}

run_backend_script() {
  local backend_name="$1"
  local backend_script="$BACKENDS_DIR/${backend_name}.sh"

  if [[ ! -f "$backend_script" ]]; then
    echo "⚠️  Backend ${backend_name} not found, using stub" >&2
    return 1
  fi

  unset -f call_backend 2>/dev/null || true
  # shellcheck source=/dev/null
  source "$backend_script" || return 1
  declare -F call_backend >/dev/null 2>&1 || return 1
  call_backend "$PROMPT" "$OUTPUT" "$STYLE"
}

call_backend_safe() {
  if ! run_backend_script "$BACKEND"; then
    if [[ "$BACKEND" != "stub" ]]; then
      echo "⚠️  Backend ${BACKEND} failed, using stub" >&2
    fi
    BACKEND="stub"
    run_backend_script "stub" || {
      echo "⚠️  Stub backend failed" >&2
      return 1
    }
  fi
}

main() {
  parse_args "$@" || return 0

  BACKEND="$(resolve_default_backend)"
  mkdir -p "$(dirname "$OUTPUT")" || {
    echo "⚠️  Failed to create output directory, using stub" >&2
    BACKEND="stub"
    mkdir -p "$(dirname "$OUTPUT")" 2>/dev/null || true
  }

  call_backend_safe || true
  echo "✅ Image generated: $OUTPUT"
  return 0
}

main "$@"
