#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

require_cmds jq

if [[ "${1:-}" == "" ]]; then
  echo "usage: $0 '<incident_json>'" >&2
  exit 1
fi

incident_json="$1"

payload="$(jq -nc --argjson i "$incident_json" '{
  type: "cloud_outage_notice",
  provider: $i.provider,
  status: $i.status,
  title: $i.title,
  summary: $i.summary,
  url: $i.url,
  updated_at: $i.updated_at,
  incident_id: $i.incident_id
}')"

if [[ "$OPENCLAW_NOTIFY_MODE" == "command" ]]; then
  if [[ -z "$OPENCLAW_NOTIFY_COMMAND" ]]; then
    echo "OPENCLAW_NOTIFY_COMMAND must be set when OPENCLAW_NOTIFY_MODE=command" >&2
    exit 2
  fi
  printf '%s\n' "$payload" | bash -lc "$OPENCLAW_NOTIFY_COMMAND"
else
  printf '%s\n' "$payload"
fi
