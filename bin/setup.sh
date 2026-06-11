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

join_with_fallback() {
  local agent="$1"
  local primary_type="$2"
  local fallback_type="$3"

  if ! join_agent "$agent" "$primary_type"; then
    printf 'Warning: official join.sh rejected type=%s; retrying %s as type=%s for this agmsg version.\n' "$primary_type" "$agent" "$fallback_type" >&2
    join_agent "$agent" "$fallback_type"
  fi
}

join_with_fallback "openclaw" "openclaw" "${AGMSG_OPENCLAW_FALLBACK_TYPE:-codex}"
join_with_fallback "hermes" "hermes" "${AGMSG_HERMES_FALLBACK_TYPE:-codex}"

printf 'Setup complete: team=%s agents=claude,openclaw,hermes\n' "$TEAM"
