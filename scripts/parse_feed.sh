#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

require_cmds curl xmllint jq sha256sum

if [[ "${1:-}" == "" ]]; then
  echo "usage: $0 <feed_url>" >&2
  exit 1
fi

feed_url="$1"
provider="$(provider_from_url "$feed_url")"

tmp_xml="$(mktemp)"
trap 'rm -f "$tmp_xml"' EXIT

if ! curl -fsSL --max-time "$FETCH_TIMEOUT_SECONDS" "$feed_url" -o "$tmp_xml"; then
  echo "failed to fetch feed: $feed_url" >&2
  exit 2
fi

rss_count="$(xmllint --xpath 'count(//*[local-name()="item"])' "$tmp_xml" 2>/dev/null | cut -d'.' -f1 || true)"
atom_count="$(xmllint --xpath 'count(//*[local-name()="entry"])' "$tmp_xml" 2>/dev/null | cut -d'.' -f1 || true)"

if [[ -z "$rss_count" ]]; then rss_count=0; fi
if [[ -z "$atom_count" ]]; then atom_count=0; fi

emit_item_json() {
  local title="$1"
  local summary="$2"
  local category="$3"
  local link="$4"
  local updated_at="$5"

  local status_text
  status_text="$title $summary $category"
  local status
  status="$(normalize_status "$status_text")"

  if [[ -z "$updated_at" ]]; then
    updated_at="$(now_utc)"
  fi

  local incident_id
  incident_id="$(incident_id_from_fields "$provider" "$link" "$updated_at" "$title")"

  jq -nc \
    --arg provider "$provider" \
    --arg incident_id "$incident_id" \
    --arg title "$title" \
    --arg status "$status" \
    --arg updated_at "$updated_at" \
    --arg url "$link" \
    --arg summary "$summary" \
    --arg raw_category "$category" \
    --arg feed_url "$feed_url" \
    '{provider:$provider,incident_id:$incident_id,title:$title,status:$status,updated_at:$updated_at,url:$url,summary:$summary,raw_category:$raw_category,feed_url:$feed_url}'
}

if [[ "$rss_count" -gt 0 ]]; then
  for ((i=1; i<=rss_count; i++)); do
    title="$(xmllint --xpath "string((//*[local-name()='item'])[$i]/*[local-name()='title'][1])" "$tmp_xml" 2>/dev/null || true)"
    summary="$(xmllint --xpath "string((//*[local-name()='item'])[$i]/*[local-name()='description'][1])" "$tmp_xml" 2>/dev/null || true)"
    category="$(xmllint --xpath "string((//*[local-name()='item'])[$i]/*[local-name()='category'][1])" "$tmp_xml" 2>/dev/null || true)"
    link="$(xmllint --xpath "string((//*[local-name()='item'])[$i]/*[local-name()='link'][1])" "$tmp_xml" 2>/dev/null || true)"
    updated_at="$(xmllint --xpath "string((//*[local-name()='item'])[$i]/*[local-name()='pubDate'][1])" "$tmp_xml" 2>/dev/null || true)"

    emit_item_json "$title" "$summary" "$category" "$link" "$updated_at"
  done
elif [[ "$atom_count" -gt 0 ]]; then
  for ((i=1; i<=atom_count; i++)); do
    title="$(xmllint --xpath "string((//*[local-name()='entry'])[$i]/*[local-name()='title'][1])" "$tmp_xml" 2>/dev/null || true)"
    summary="$(xmllint --xpath "string((//*[local-name()='entry'])[$i]/*[local-name()='summary'][1])" "$tmp_xml" 2>/dev/null || true)"
    if [[ -z "$summary" ]]; then
      summary="$(xmllint --xpath "string((//*[local-name()='entry'])[$i]/*[local-name()='content'][1])" "$tmp_xml" 2>/dev/null || true)"
    fi
    category="$(xmllint --xpath "string((//*[local-name()='entry'])[$i]/*[local-name()='category'][1]/@term)" "$tmp_xml" 2>/dev/null || true)"
    link="$(xmllint --xpath "string((//*[local-name()='entry'])[$i]/*[local-name()='link'][1]/@href)" "$tmp_xml" 2>/dev/null || true)"
    updated_at="$(xmllint --xpath "string((//*[local-name()='entry'])[$i]/*[local-name()='updated'][1])" "$tmp_xml" 2>/dev/null || true)"

    emit_item_json "$title" "$summary" "$category" "$link" "$updated_at"
  done
else
  # Valid feeds can occasionally have zero entries; treat this as a no-op.
  exit 0
fi
