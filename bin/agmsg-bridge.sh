#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: bin/agmsg-bridge.sh <team> <agent> <adapter> [--interval N|--once]

Poll agmsg unread messages for <team>/<agent> using the official inbox.sh
script. When unread messages exist, dispatch a wake prompt to <adapter>.

Adapters:
  openclaw    openclaw agent -m "<wake>" --json, then --local fallback
  hermes      hermes -z "<wake>" --yolo --max-turns 6, then current-CLI fallback
USAGE
}

if [ "$#" -lt 3 ]; then
  usage >&2
  exit 2
fi

TEAM="$1"
AGENT="$2"
ADAPTER="$3"
shift 3

INTERVAL=15
ONCE=false

while [ "$#" -gt 0 ]; do
  case "$1" in
    --interval)
      if [ "$#" -lt 2 ]; then
        echo "--interval requires a number" >&2
        exit 2
      fi
      INTERVAL="$2"
      shift 2
      ;;
    --once)
      ONCE=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "$INTERVAL" in
  ''|*[!0-9]*)
    echo "--interval must be a positive integer" >&2
    exit 2
    ;;
  0)
    echo "--interval must be greater than zero" >&2
    exit 2
    ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGMSG_SCRIPTS_DIR="${AGMSG_SCRIPTS_DIR:-/Users/takumihayashi/.agents/skills/agmsg/scripts}"
INBOX_SH="$AGMSG_SCRIPTS_DIR/inbox.sh"
AGMSG_BIN="${AGMSG_BIN:-/opt/homebrew/bin/agmsg}"
OPENCLAW_BIN="${OPENCLAW_BIN:-/opt/homebrew/bin/openclaw}"
OPENCLAW_AGENT_ID="${OPENCLAW_AGENT_ID:-}"
OPENCLAW_DELIVER="${OPENCLAW_DELIVER:-1}"
OPENCLAW_REPLY_CHANNEL="${OPENCLAW_REPLY_CHANNEL:-last}"
OPENCLAW_REPLY_TO="${OPENCLAW_REPLY_TO:-}"
OPENCLAW_REPLY_ACCOUNT="${OPENCLAW_REPLY_ACCOUNT:-}"
HERMES_BIN="${HERMES_BIN:-$HOME/.local/bin/hermes}"
HERMES_MAX_TURNS="${HERMES_MAX_TURNS:-6}"
HERMES_SKILLS="${HERMES_SKILLS:-agmsg-protocol}"
SAFE_TEAM="$(printf '%s' "$TEAM" | tr -c 'A-Za-z0-9_.-' '_')"
SAFE_AGENT="$(printf '%s' "$AGENT" | tr -c 'A-Za-z0-9_.-' '_')"
LOG_FILE="$SCRIPT_DIR/.bridge-$SAFE_TEAM-$SAFE_AGENT.log"
LOCK_DIR="$SCRIPT_DIR/.bridge-$SAFE_TEAM-$SAFE_AGENT.lock"

timestamp() {
  date -u '+%Y-%m-%dT%H:%M:%SZ'
}

log() {
  printf '[%s] %s\n' "$(timestamp)" "$*" >> "$LOG_FILE"
}

compact() {
  printf '%s' "$1" | tr '\n' ' ' | sed 's/[[:space:]][[:space:]]*/ /g' | cut -c 1-4000
}

cleanup() {
  rmdir "$LOCK_DIR" 2>/dev/null || true
}

acquire_lock() {
  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    log "lock_held team=$TEAM agent=$AGENT adapter=$ADAPTER"
    echo "Bridge already running for $TEAM/$AGENT" >&2
    exit 0
  fi
  trap cleanup EXIT INT TERM
}

require_file() {
  if [ ! -x "$1" ]; then
    log "missing_executable path=$1"
    echo "Missing executable: $1" >&2
    exit 2
  fi
}

message_froms() {
  sed -n 's/^  \[[^]]*\] \([^:][^:]*\): .*/\1/p' | sort -u
}

build_wake_prompt() {
  local inbox_output="$1"
  local froms first_from

  froms="$(printf '%s\n' "$inbox_output" | message_froms | paste -sd ',' -)"
  first_from="$(printf '%s\n' "$froms" | cut -d ',' -f 1)"
  if [ -z "$froms" ]; then
    froms="unknown"
  fi
  if [ -z "$first_from" ]; then
    first_from="<from>"
  fi

  cat <<EOF
あなたは agmsg team "$TEAM" の agent "$AGENT" として呼び出されています。

agmsg の公式 inbox.sh が新着メッセージを取得しました。以下が新着本文の全文です。

$inbox_output

必須プロトコル:
- 返信が必要な各メッセージについて、必ず次の形式のコマンドを実行してください。
  $AGMSG_BIN send $TEAM $AGENT <from> "<返信本文>"
- 今回の送信者候補: $froms
- 1件だけ返信する場合は、必ず次を実行してください。
  $AGMSG_BIN send $TEAM $AGENT $first_from "<返信本文>"
- 返信本文には依頼への答えを含めてください。
- コマンドを実行した後は、実行結果だけを短く報告してください。
EOF
}

openclaw_needs_agent() {
  case "$1" in
    *"No target session selected"*|*"Pass --to <E.164>, --session-key, --session-id, or --agent"*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

resolve_openclaw_agent_id() {
  local output agent_id

  if [ -n "$OPENCLAW_AGENT_ID" ]; then
    printf '%s\n' "$OPENCLAW_AGENT_ID"
    return 0
  fi

  if ! output=$("$OPENCLAW_BIN" agents list 2>&1); then
    log "adapter=openclaw agents_list_failed output=$(compact "$output")"
    return 1
  fi

  agent_id="$(printf '%s\n' "$output" | sed -n 's/^- \([^ ]*\) (default).*/\1/p' | head -n 1)"
  if [ -z "$agent_id" ]; then
    log "adapter=openclaw default_agent_not_found output=$(compact "$output")"
    return 1
  fi

  printf '%s\n' "$agent_id"
}

OPENCLAW_LAST_OUTPUT=""
OPENCLAW_LAST_STATUS=0

run_openclaw_command() {
  local label="$1"
  local output status
  shift

  log "adapter=openclaw ${label}_start"
  if output=$("$OPENCLAW_BIN" agent "$@" 2>&1); then
    log "adapter=openclaw ${label}_success output=$(compact "$output")"
    return 0
  else
    status=$?
    OPENCLAW_LAST_OUTPUT="$output"
    OPENCLAW_LAST_STATUS="$status"
    log "adapter=openclaw ${label}_failed exit=$status output=$(compact "$output")"
    return "$status"
  fi
}

run_openclaw() {
  local wake_prompt="$1"
  local agent_id
  local -a delivery_args

  if [ ! -x "$OPENCLAW_BIN" ]; then
    log "adapter=openclaw missing_executable path=$OPENCLAW_BIN"
    return 1
  fi

  delivery_args=()
  case "$OPENCLAW_DELIVER" in
    0|false|FALSE|off|OFF|no|NO)
      ;;
    *)
      delivery_args+=(--deliver)
      ;;
  esac
  if [ -n "$OPENCLAW_REPLY_CHANNEL" ]; then
    delivery_args+=(--reply-channel "$OPENCLAW_REPLY_CHANNEL")
  fi
  if [ -n "$OPENCLAW_REPLY_TO" ]; then
    delivery_args+=(--reply-to "$OPENCLAW_REPLY_TO")
  fi
  if [ -n "$OPENCLAW_REPLY_ACCOUNT" ]; then
    delivery_args+=(--reply-account "$OPENCLAW_REPLY_ACCOUNT")
  fi
  log "adapter=openclaw delivery deliver=$OPENCLAW_DELIVER reply_channel=${OPENCLAW_REPLY_CHANNEL:-none} reply_to=${OPENCLAW_REPLY_TO:-none} reply_account=${OPENCLAW_REPLY_ACCOUNT:-none}"

  if run_openclaw_command "gateway" -m "$wake_prompt" "${delivery_args[@]}" --json; then
    return 0
  fi

  if openclaw_needs_agent "$OPENCLAW_LAST_OUTPUT"; then
    if ! agent_id="$(resolve_openclaw_agent_id)"; then
      log "adapter=openclaw cannot_resolve_agent_after_target_error"
      return 1
    fi
    log "adapter=openclaw resolved_agent=$agent_id"

    if run_openclaw_command "gateway_with_agent" --agent "$agent_id" -m "$wake_prompt" "${delivery_args[@]}" --json; then
      return 0
    fi

    if run_openclaw_command "local_fallback_with_agent" --agent "$agent_id" -m "$wake_prompt" "${delivery_args[@]}" --json --local; then
      return 0
    fi

    return 1
  fi

  if run_openclaw_command "local_fallback" -m "$wake_prompt" "${delivery_args[@]}" --json --local; then
    return 0
  fi

  return 1
}

HERMES_LAST_OUTPUT=""
HERMES_LAST_STATUS=0

run_hermes_command() {
  local label="$1"
  local output status
  shift

  log "adapter=hermes ${label}_start"
  if output=$("$HERMES_BIN" "$@" 2>&1); then
    log "adapter=hermes ${label}_success output=$(compact "$output")"
    return 0
  else
    status=$?
    HERMES_LAST_OUTPUT="$output"
    HERMES_LAST_STATUS="$status"
    log "adapter=hermes ${label}_failed exit=$status output=$(compact "$output")"
    return "$status"
  fi
}

hermes_max_turns_unsupported() {
  case "$1" in
    *"invalid choice: '6'"*|*"unrecognized arguments: --max-turns"*|*"ambiguous option: --max-turns"*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

run_hermes() {
  local wake_prompt="$1"
  local -a skill_args

  if [ ! -x "$HERMES_BIN" ]; then
    log "adapter=hermes missing_executable path=$HERMES_BIN"
    return 1
  fi

  skill_args=()
  if [ -n "$HERMES_SKILLS" ]; then
    skill_args+=(--skills "$HERMES_SKILLS")
  fi

  if run_hermes_command "oneshot_max_turns" -z "$wake_prompt" --yolo --max-turns "$HERMES_MAX_TURNS" "${skill_args[@]}"; then
    return 0
  fi

  if hermes_max_turns_unsupported "$HERMES_LAST_OUTPUT"; then
    log "adapter=hermes max_turns_unsupported_retry_without_max_turns"

    if run_hermes_command "oneshot" -z "$wake_prompt" --yolo "${skill_args[@]}"; then
      return 0
    fi
  fi

  return 1
}

dispatch_adapter() {
  local wake_prompt="$1"

  case "$ADAPTER" in
    openclaw)
      run_openclaw "$wake_prompt"
      ;;
    hermes)
      run_hermes "$wake_prompt"
      ;;
    *)
      log "unknown_adapter adapter=$ADAPTER"
      echo "Unknown adapter: $ADAPTER" >&2
      return 2
      ;;
  esac
}

poll_once() {
  local inbox_output wake_prompt

  if ! inbox_output=$("$INBOX_SH" "$TEAM" "$AGENT" --quiet 2>&1); then
    log "inbox_failed team=$TEAM agent=$AGENT output=$(compact "$inbox_output")"
    echo "inbox.sh failed for $TEAM/$AGENT" >&2
    return 0
  fi

  if [ -z "$inbox_output" ]; then
    log "no_new_messages team=$TEAM agent=$AGENT"
    echo "No new messages for $TEAM/$AGENT"
    return 0
  fi

  log "new_messages team=$TEAM agent=$AGENT output=$(compact "$inbox_output")"
  wake_prompt="$(build_wake_prompt "$inbox_output")"
  log "wake_prompt team=$TEAM agent=$AGENT adapter=$ADAPTER prompt=$(compact "$wake_prompt")"

  if dispatch_adapter "$wake_prompt"; then
    log "dispatch_success team=$TEAM agent=$AGENT adapter=$ADAPTER"
    echo "Dispatched new messages for $TEAM/$AGENT to $ADAPTER"
  else
    log "dispatch_failed_skipped team=$TEAM agent=$AGENT adapter=$ADAPTER"
    echo "Adapter failed; skipped messages for $TEAM/$AGENT (see $LOG_FILE)" >&2
  fi

  return 0
}

require_file "$INBOX_SH"
acquire_lock
log "bridge_start team=$TEAM agent=$AGENT adapter=$ADAPTER once=$ONCE interval=$INTERVAL"

if [ "$ONCE" = true ]; then
  poll_once
  log "bridge_stop team=$TEAM agent=$AGENT reason=once"
  exit 0
fi

while true; do
  poll_once || true
  sleep "$INTERVAL"
done
