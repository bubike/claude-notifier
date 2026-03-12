# claude-notifier

A lightweight local microservice that bridges Claude Code (running in Docker/devcontainers) with macOS native notifications. Get desktop alerts when Claude needs your attention, finishes work, or hits an error -- even when it's running headlessly in a container.

Also includes an `/ensure-chrome` endpoint that auto-launches Chrome with remote debugging, useful as a Claude Code hook to recover from Chrome DevTools MCP failures.

## How it works

```
┌──────────────────────┐       HTTP POST        ┌─────────────────────┐
│  Claude Code (hook)  │  ───────────────────►   │  claude-notifier    │
│  inside devcontainer │   host.docker.internal  │  on macOS host      │
└──────────────────────┘        :3333            └────────┬────────────┘
                                                          │
                                                          ▼
                                                   macOS notification
                                                   (osascript + Glass)
```

1. **Server** (`main.js`) -- Express app on port 3333 with two endpoints:
   - `POST /notify` -- triggers a macOS notification via `osascript`
   - `POST /ensure-chrome` -- starts Chrome with `--remote-debugging-port=9222` if it isn't already running
2. **Hook scripts** (`hooks/`) -- Shell scripts designed to be used as [Claude Code hooks](https://docs.anthropic.com/en/docs/claude-code/hooks):
   - `notfy.sh` -- Sends notifications on Claude events (Stop, Notification, errors, permission prompts)
   - `ensure-chrome.sh` -- Auto-recovers from Chrome DevTools MCP tool failures
3. **LaunchAgent installer** (`install-server.sh`) -- Registers the server as a macOS LaunchAgent so it starts on login and stays alive

## Setup

### 1. Install and start the server

```bash
git clone <repo-url> && cd claude-notifier
npm install
bash install-server.sh
```

This registers a LaunchAgent (`com.local.claude-notifier`) that keeps the server running in the background.

### 2. Configure Claude Code hooks

Copy the hook scripts into your project's `.claude/hooks/` directory and add the hook configuration to your `.claude/settings.json`:

```bash
mkdir -p .claude/hooks
cp hooks/notfy.sh .claude/hooks/notify.sh
cp hooks/ensure-chrome.sh .claude/hooks/ensure-chrome.sh
chmod +x .claude/hooks/*.sh
```

Then add to `.claude/settings.json` (or merge with existing):

```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/notify.sh $ARGUMENTS"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/notify.sh \"✅ Work completed\""
          }
        ]
      }
    ],
    "PostToolUseFailure": [
      {
        "matcher": "mcp__chrome-devtools",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/ensure-chrome.sh",
            "statusMessage": "Ensuring Chrome DevTools is running..."
          }
        ]
      }
    ]
  }
}
```

## API

### `POST /notify`

Trigger a macOS desktop notification.

| Field      | Type   | Default                  | Description            |
|------------|--------|--------------------------|------------------------|
| `title`    | string | `"Claude Notification"`  | Notification title     |
| `subtitle` | string | _(none)_                 | Notification subtitle  |
| `message`  | string | `""`                     | Notification body text |

**Header:** `X-Dev-Secret: devcontainer-local-only` (configurable via `NOTIFY_SECRET` env var)

### `POST /ensure-chrome`

Start Chrome with remote debugging if not already running.

Returns `{ "ok": true, "started": true }` if Chrome was launched, or `{ "ok": true, "started": false }` if it was already running.

## Managing the service

```bash
# Check status
launchctl list | grep claude-notifier

# View logs
tail -f claude-notifier.log

# Stop
launchctl unload ~/Library/LaunchAgents/com.local.claude-notifier.plist

# Start
launchctl load ~/Library/LaunchAgents/com.local.claude-notifier.plist
```

## Requirements

- macOS
- Node.js
- Google Chrome (for the `/ensure-chrome` endpoint)

## License

MIT
