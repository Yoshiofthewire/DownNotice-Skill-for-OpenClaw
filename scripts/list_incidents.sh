#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

require_cmds jq

limit="${1:-$LIST_LIMIT}"

if ! [[ "$limit" =~ ^[0-9]+$ ]]; then
  echo "limit must be a positive integer" >&2
  exit 1
fi

tmp_jsonl="$(mktemp)"
trap 'rm -f "$tmp_jsonl"' EXIT

feed_failed=0
for feed in "${FEEDS[@]}"; do
  if ! "$SCRIPT_DIR/parse_feed.sh" "$feed" >> "$tmp_jsonl"; then
    echo "warning: unable to parse $feed" >&2
    feed_failed=1
  fi
done

jq -sr --argjson limit "$limit" '
  map(select((.status == "disrupted" or .status == "down" or .status == "resolved") and .status != "scheduled"))
  | unique_by(.incident_id)
  | sort_by(.updated_at)
  | reverse
  | .[:$limit]
  | map("[\(.provider)] [\(.status)] \(.title)\n  updated: \(.updated_at)\n  link: \(.url)")
  | if length == 0 then "No matching incidents found." else .[] end
' "$tmp_jsonl"

if [[ "$feed_failed" -eq 1 ]]; then
  exit 10
fi
