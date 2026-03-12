#!/bin/bash
# Sends HTTP notification with dynamic worktree name from git branch

INPUT="$1"
ENDPOINT="http://host.docker.internal:3333/notify"

# Extract repository name from git remote
REPO=$(git -C "$CLAUDE_PROJECT_DIR" remote get-url origin 2>/dev/null | sed 's/.*[:/]\([^/]*\/[^/]*\)\.git$/\1/' || echo "local")
BRANCH=$(git -C "$CLAUDE_PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

# Format title and subtitle
TITLE="Claude at ${BRANCH}"
SUBTITLE="${REPO}"

# Parse JSON input to extract message and notification_type
if echo "$INPUT" | jq -e . >/dev/null 2>&1; then
  # Input is JSON, parse it
  RAW_MESSAGE=$(echo "$INPUT" | jq -r '.message // empty')
  NOTIFICATION_TYPE=$(echo "$INPUT" | jq -r '.notification_type // empty')
  HOOK_EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // empty')

  # Prepend emoji/text based on notification type or event
  case "$NOTIFICATION_TYPE" in
    permission_prompt)
      MESSAGE="🔐 $RAW_MESSAGE"
      ;;
    error)
      MESSAGE="❌ $RAW_MESSAGE"
      ;;
    warning)
      MESSAGE="⚠️ $RAW_MESSAGE"
      ;;
    success)
      MESSAGE="✅ $RAW_MESSAGE"
      ;;
    info)
      MESSAGE="ℹ️ $RAW_MESSAGE"
      ;;
    *)
      # Check hook event name if notification_type is not set
      case "$HOOK_EVENT" in
        Stop)
          MESSAGE="✅ Work completed"
          ;;
        *)
          # Use raw message or default
          MESSAGE="${RAW_MESSAGE:-$INPUT}"
          ;;
      esac
      ;;
  esac
else
  # Input is plain text, use as-is
  MESSAGE="$INPUT"
fi

# Send notification
curl -s -X POST "$ENDPOINT" \
  -H "Content-Type: application/json" \
  -H "X-Dev-Secret: devcontainer-local-only" \
  -d "{\"message\":\"$MESSAGE\",\"title\":\"$TITLE\",\"subtitle\":\"$SUBTITLE\"}" \
  > /dev/null 2>&1

exit 0
