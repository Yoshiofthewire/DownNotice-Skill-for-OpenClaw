# DownNotice Skill for OpenClaw

DownNotice is a bash-based OpenClaw skill scaffold that monitors cloud status feeds and emits outage notices.

Current implementation goals:
- Poll cloud status RSS/Atom feeds.
- Normalize incidents to a common format.
- Notify only for `disrupted`, `down`, and `resolved` incidents.
- Skip `scheduled` incidents.
- Provide a command to list recent matching incidents.

## Implemented Files

- `SKILL.md` - OpenClaw skill definition parsed by the LLM.
- `config/defaults.env` - feed URLs, filters, notify mode, and runtime defaults.
- `scripts/poll.sh` - main polling flow with per-run deduplication.
- `scripts/parse_feed.sh` - fetch + parse RSS/Atom into normalized JSON lines.
- `scripts/notify.sh` - OpenClaw notification adapter (stdout or command mode).
- `scripts/list_incidents.sh` - list recent incidents from live feeds.
- `scripts/common.sh` - shared helpers.

## Dependencies

Required tools:
- `bash`
- `curl`
- `xmllint`
- `jq`
- `sha256sum`

Ubuntu/Debian example:

```bash
sudo apt-get update
sudo apt-get install -y curl jq libxml2-utils coreutils
```

## Configuration

Defaults live in `config/defaults.env`.

Important values:
- `FEEDS`: source feed URLs.
- `INCLUDE_STATUSES`: statuses that trigger notification.
- `EXCLUDE_STATUSES`: statuses that are always ignored.
- `OPENCLAW_NOTIFY_MODE`: `stdout` or `command`.
- `OPENCLAW_NOTIFY_COMMAND`: command that accepts JSON payload on stdin when mode is `command`.
- `LIST_LIMIT`: default maximum records returned by list command.

## Run Locally

Mark scripts executable (one time):

```bash
chmod +x scripts/*.sh
```

Run one polling pass:

```bash
./scripts/poll.sh
```

List recent incidents (default limit from config):

```bash
./scripts/list_incidents.sh
```

List recent incidents with explicit limit:

```bash
./scripts/list_incidents.sh 10
```

## OpenClaw Notification Integration

By default, notifications are printed to stdout.

To route notifications into OpenClaw command execution:

1. Set in `config/defaults.env`:

```bash
OPENCLAW_NOTIFY_MODE="command"
OPENCLAW_NOTIFY_COMMAND="openclaw notify"
```

2. Ensure your command can read payload JSON from stdin.

Payload example:

```json
{
	"type": "cloud_outage_notice",
	"provider": "github",
	"status": "resolved",
	"title": "Disruption with some GitHub services",
	"summary": "...",
	"url": "https://www.githubstatus.com/incidents/...",
	"updated_at": "Wed, 22 Apr 2026 22:43:59 +0000",
	"incident_id": "..."
}
```

## Schedule Every 15 Minutes

Use external scheduling (cron or systemd timer).

### Cron

```cron
*/15 * * * * cd /path/to/DownNotice\ Skill\ for\ OpenClaw && ./scripts/poll.sh >> downnotice.log 2>&1
```

### systemd timer

Use a service that runs `scripts/poll.sh` and a timer with:

```ini
OnCalendar=*:0/15
Persistent=true
```

## Known Limitations

- Deduplication is in-memory per process run only.
- Restarting or rerunning can re-emit previously seen incidents.
- Some provider feeds may be empty at times, resulting in no output.

## Development Baseline

OpenClaw docs:
- https://docs.openclaw.ai/tools/skills

OpenClaw skill file format:
- `SKILL.md` is the runtime skill definition file.

Default feed sources:
- https://azure.status.microsoft/en-us/status/feed/
- https://status.aws.amazon.com/rss/all.rss
- https://status.cloud.google.com/en/feed.atom
- https://www.githubstatus.com/history.rss
- https://www.cloudflarestatus.com/history.atom

