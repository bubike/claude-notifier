#!/bin/bash
# ensure-chrome.sh — PostToolUseFailure hook for chrome-devtools MCP tools
# Calls the host's ensure-chrome endpoint to start Chrome if it's not running,
# then tells Claude to retry the tool call.

INPUT=$(cat)

RESPONSE=$(curl -sf -X POST http://host.docker.internal:3333/ensure-chrome \
  -H 'Content-Type: application/json' \
  -H 'x-dev-secret: devcontainer-local-only' \
  -d '{}' 2>&1)

CURL_EXIT=$?

if [ $CURL_EXIT -ne 0 ]; then
  echo "Failed to reach ensure-chrome endpoint: $RESPONSE" >&2
  exit 2
fi

STARTED=$(echo "$RESPONSE" | jq -r '.started // empty')

if [ "$STARTED" = "true" ]; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PostToolUseFailure",
      additionalContext: "Chrome was not running. It has now been started with remote debugging on port 9222. Please retry the failed tool call."
    }
  }'
elif [ "$STARTED" = "false" ]; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PostToolUseFailure",
      additionalContext: "Chrome is already running on port 9222. The tool failure may be caused by something else. Check the error details and retry."
    }
  }'
else
  echo "Unexpected response from ensure-chrome: $RESPONSE" >&2
  exit 2
fi
