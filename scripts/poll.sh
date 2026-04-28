#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

require_cmds jq

declare -A seen=()
declare -a recent=()

max_recent="${LIST_LIMIT:-20}"

should_notify() {
  local status="$1"

  if contains_item "$status" "${EXCLUDE_STATUSES[@]}"; then
    return 1
  fi

  if contains_item "$status" "${INCLUDE_STATUSES[@]}"; then
    return 0
  fi

  return 1
}

process_incident() {
  local incident_json="$1"

  local incident_id
  incident_id="$(jq -r '.incident_id' <<<"$incident_json")"
  local status
  status="$(jq -r '.status' <<<"$incident_json")"

  if [[ -n "${seen[$incident_id]:-}" ]]; then
    return 0
  fi

  seen[$incident_id]=1
  recent+=("$incident_json")

  if [[ "${#recent[@]}" -gt "$max_recent" ]]; then
    recent=("${recent[@]:1}")
  fi

  if should_notify "$status"; then
    "$SCRIPT_DIR/notify.sh" "$incident_json"
  fi
}

main() {
  local feed
  local parse_rc
  local line
  local had_errors=0

  for feed in "${FEEDS[@]}"; do
    while IFS= read -r line; do
      if [[ -n "$line" ]]; then
        process_incident "$line"
      fi
    done < <("$SCRIPT_DIR/parse_feed.sh" "$feed") || parse_rc=$?

    parse_rc="${parse_rc:-0}"
    if [[ "$parse_rc" -ne 0 ]]; then
      echo "feed processing failed: $feed (exit=$parse_rc)" >&2
      had_errors=1
      parse_rc=0
    fi
  done

  if [[ "$had_errors" -eq 1 ]]; then
    return 10
  fi

  return 0
}

main "$@"
