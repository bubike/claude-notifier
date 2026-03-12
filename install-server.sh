#!/usr/bin/env bash
set -e

SERVICE_NAME="com.local.claude-notifier"
SCRIPT_PATH="$(pwd)/main.js"
PLIST_PATH="$HOME/Library/LaunchAgents/$SERVICE_NAME.plist"
LOG_PATH="$(pwd)/claude-notifier.log"

echo "Installing notify server service..."
echo

# Check script exists
if [ ! -f "$SCRIPT_PATH" ]; then
  echo "❌ main.js not found in current directory"
  exit 1
fi

# Detect node path (works with nvm)
NODE_PATH="$(which node)"

if [ -z "$NODE_PATH" ]; then
  echo "❌ Node not found in PATH"
  exit 1
fi

echo "Using Node: $NODE_PATH"
echo "Server script: $SCRIPT_PATH"
echo

mkdir -p "$HOME/Library/LaunchAgents"

cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>

  <key>Label</key>
  <string>$SERVICE_NAME</string>

  <key>ProgramArguments</key>
  <array>
    <string>$NODE_PATH</string>
    <string>$SCRIPT_PATH</string>
  </array>

  <key>RunAtLoad</key>
  <true/>

  <key>KeepAlive</key>
  <true/>

  <key>StandardOutPath</key>
  <string>$LOG_PATH</string>

  <key>StandardErrorPath</key>
  <string>$LOG_PATH</string>

</dict>
</plist>
EOF

echo "Service file created:"
echo "$PLIST_PATH"
echo

echo "Reloading service..."

launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH"

echo
echo "✅ Service installed and started"
echo
echo "Useful commands:"
echo "--------------------------------"
echo "Check service:"
echo "launchctl list | grep notify"
echo
echo "View logs:"
echo "tail -f $LOG_PATH"
echo
echo "Stop service:"
echo "launchctl unload $PLIST_PATH"
echo
echo "Start service:"
echo "launchctl load $PLIST_PATH"