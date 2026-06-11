#!/usr/bin/env bash
set -euo pipefail

TEAM="${1:-bridge-e2e}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
AGMSG_SCRIPTS_DIR="${AGMSG_SCRIPTS_DIR:-/Users/takumihayashi/.agents/skills/agmsg/scripts}"
JOIN_SH="$AGMSG_SCRIPTS_DIR/join.sh"

if [ ! -x "$JOIN_SH" ]; then
  echo "Missing executable: $JOIN_SH" >&2
  exit 2
fi

join_agent() {
  local agent="$1"
  local type="$2"
  local output

  if output=$("$JOIN_SH" "$TEAM" "$agent" "$type" "$PROJECT_DIR" 2>&1); then
    printf '%s\n' "$output"
    return 0
  fi

  printf '%s\n' "$output" >&2
  return 1
}

join_agent "claude" "claude-code"

if ! join_agent "openclaw" "openclaw"; then
  fallback_type="${AGMSG_OPENCLAW_FALLBACK_TYPE:-codex}"
  printf 'Warning: official join.sh rejected type=openclaw; retrying openclaw as type=%s for this agmsg version.\n' "$fallback_type" >&2
  join_agent "openclaw" "$fallback_type"
fi

printf 'Setup complete: team=%s agents=claude,openclaw\n' "$TEAM"
