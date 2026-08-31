#!/bin/bash
# OutAbout — continuous verification loop.
# Run once:  bash ~/outabout/agent-verify.sh
# Leave it running. It re-runs analyze + tests whenever lib/ or test/ changes,
# and writes results to .agent/verify.log which the agent reads.

cd "$(dirname "$0")" || exit 1
mkdir -p .agent
LOG=".agent/verify.log"
CMDFILE=".agent/command.txt"
LAST=""

echo "OutAbout verify loop running. Ctrl-C to stop."
while true; do
  # 1. Run any one-off command the agent has queued.
  if [ -s "$CMDFILE" ]; then
    CMD="$(cat "$CMDFILE")"
    : > "$CMDFILE"
    {
      echo "=== QUEUED COMMAND @ $(date '+%Y-%m-%d %H:%M:%S') ==="
      echo "\$ $CMD"
      eval "$CMD" 2>&1
      echo "=== exit=$? ==="
    } > .agent/command.log
  fi

  # 2. Re-run analyze + tests when sources change.
  SIG="$(find lib test pubspec.yaml ios/Runner android/app -type f \( -name '*.dart' -o -name '*.yaml' -o -name '*.plist' -o -name '*.xml' -o -name '*.gradle*' -o -name '*.pbxproj' -o -name '*.xcprivacy' \) -exec stat -f '%m %N' {} + 2>/dev/null | sort | shasum | cut -d' ' -f1)"
  if [ "$SIG" != "$LAST" ]; then
    LAST="$SIG"
    {
      echo "########## RUN @ $(date '+%Y-%m-%d %H:%M:%S') ##########"
      echo "----- flutter pub get -----"
      flutter pub get 2>&1 | tail -5
      echo "----- flutter analyze -----"
      flutter analyze 2>&1 | tail -120
      echo "----- flutter test -----"
      flutter test --reporter=compact 2>&1 | tail -80
      echo "########## END ##########"
    } > "$LOG"
    echo "[$(date '+%H:%M:%S')] verified — results in .agent/verify.log"
  fi
  sleep 15
done
