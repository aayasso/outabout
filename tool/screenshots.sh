#!/usr/bin/env bash
set -euo pipefail

DEVICE_NAME="iPhone 17 Pro Max"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT="$REPO_ROOT/marketing/screenshots/raw/iphone_17_pro_max"

# -- Resolve UDID ---------------------------------------------------
# Prefer an already-booted device. Otherwise pick the one on the
# newest installed runtime (sorted explicitly, never dict order).

read -r UDID RUNTIME < <(xcrun simctl list devices "$DEVICE_NAME" available -j \
  | python3 -c "
import sys, json

data = json.load(sys.stdin)
candidates = []
for runtime, devs in data.get('devices', {}).items():
    for d in devs:
        if d['name'] == '$DEVICE_NAME' and d.get('isAvailable'):
            candidates.append((runtime, d['udid'], d.get('state', '')))

if not candidates:
    sys.exit(1)

# Prefer Booted, then sort by runtime descending (newest first).
candidates.sort(key=lambda c: (c[2] != 'Booted', c[0]), reverse=False)
booted = [c for c in candidates if c[2] == 'Booted']
if booted:
    pick = booted[0]
else:
    # Sort by runtime descending so newest is first.
    candidates.sort(key=lambda c: c[0], reverse=True)
    pick = candidates[0]
print(f'{pick[1]} {pick[0]}')
" 2>/dev/null) || {
  echo "ERROR: $DEVICE_NAME simulator not installed."
  exit 1
}
echo "Using $DEVICE_NAME"
echo "  UDID:    $UDID"
echo "  Runtime: $RUNTIME"

# -- Trap: always clear status bar on exit --------------------------

cleanup() {
  xcrun simctl status_bar "$UDID" clear 2>/dev/null || true
}
trap cleanup EXIT

# -- Boot -----------------------------------------------------------

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID"

# -- 12-hour clock (avoids "09:41" leading zero) --------------------

xcrun simctl spawn "$UDID" defaults write -g AppleICUForce24HourTime -bool NO

# -- Status bar -----------------------------------------------------

xcrun simctl status_bar "$UDID" override \
  --time 9:41 \
  --batteryState charged \
  --batteryLevel 100 \
  --cellularBars 4 \
  --wifiBars 3

xcrun simctl ui "$UDID" appearance light

# -- Output ---------------------------------------------------------

mkdir -p "$OUT"

DEBUG_DIR="$REPO_ROOT/marketing/screenshots/debug"
mkdir -p "$DEBUG_DIR"
LOG="$DEBUG_DIR/last_run.log"

# -- Shots ----------------------------------------------------------

SHOTS=(
  "01_browse_right_now"
  "02_forecast_week"
  "03_activity_library"
  "04_add_activity"
  "05_activity_detail"
  "05b_activity_detail_conditions"
  "06_theme_rainy"
  "07_theme_night"
  "08_onboarding"  # Optional — omit with --skip-onboarding
)

export SCREENSHOT_UDID="$UDID"
export SCREENSHOT_DIR="$OUT"

{

for shot_name in "${SHOTS[@]}"; do
  # Extract the shot key (everything before the first _).
  shot_id="${shot_name%%_*}"
  echo ""
  echo "--- Shot $shot_name (key=$shot_id) ---"
  export SHOT="$shot_name"

  flutter drive \
    --driver=test_driver/screenshot_driver.dart \
    --target=integration_test/screenshot_test.dart \
    --device-id "$UDID" \
    --dart-define="SHOT=$shot_id" \
    --no-pub \
    2>&1

  echo "--- Done $shot_name ---"
done

# -- Verify ---------------------------------------------------------

echo ""
echo "=== Screenshot dimensions ==="
for f in "$OUT"/*.png; do
  [ -f "$f" ] || continue
  echo "$(basename "$f"):"
  sips -g pixelWidth -g pixelHeight "$f" 2>/dev/null \
    | grep pixel
done
echo ""
echo "Done. Screenshots in $OUT"

} 2>&1 | tee "$LOG"
