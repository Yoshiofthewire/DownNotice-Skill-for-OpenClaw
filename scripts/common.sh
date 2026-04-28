#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DEFAULTS_FILE="$ROOT_DIR/config/defaults.env"

if [[ ! -f "$DEFAULTS_FILE" ]]; then
  echo "defaults file missing: $DEFAULTS_FILE" >&2
  exit 1
fi

# shellcheck source=/dev/null
source "$DEFAULTS_FILE"

now_utc() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

require_cmds() {
  local missing=0
  local cmd
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "missing dependency: $cmd" >&2
      missing=1
    fi
  done

  if [[ "$missing" -eq 1 ]]; then
    exit 1
  fi
}

contains_item() {
  local needle="$1"
  shift
  local item
  for item in "$@"; do
    if [[ "$item" == "$needle" ]]; then
      return 0
    fi
  done
  return 1
}

provider_from_url() {
  local url="$1"
  case "$url" in
    *azure.status.microsoft*) echo "azure" ;;
    *status.aws.amazon.com*) echo "aws" ;;
    *status.cloud.google.com*) echo "gcp" ;;
    *githubstatus.com*) echo "github" ;;
    *cloudflarestatus.com*) echo "cloudflare" ;;
    *) echo "unknown" ;;
  esac
}

normalize_status() {
  local text
  text="$(echo "$1" | tr '[:upper:]' '[:lower:]')"

  if [[ "$text" =~ scheduled|maintenance|planned ]]; then
    echo "scheduled"
    return
  fi

  if [[ "$text" =~ resolved|restored|recovered ]]; then
    echo "resolved"
    return
  fi

  if [[ "$text" =~ outage|down|unavailable|major[[:space:]]incident ]]; then
    echo "down"
    return
  fi

  if [[ "$text" =~ disrupted|degraded|partial|investigating|service[[:space:]]issue ]]; then
    echo "disrupted"
    return
  fi

  echo "unknown"
}

incident_id_from_fields() {
  local provider="$1"
  local link="$2"
  local updated_at="$3"
  local title="$4"

  printf '%s|%s|%s|%s' "$provider" "$link" "$updated_at" "$title" | sha256sum | awk '{print $1}'
}
