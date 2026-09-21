#!/usr/bin/env bash
set -euo pipefail

DEVICE_NAME="iPhone 17 Pro Max"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT="$REPO_ROOT/marketing/screenshots/raw/iphone_17_pro_max"

# -- Resolve UDID ---------------------------------------------------

UDID=$(xcrun simctl list devices "$DEVICE_NAME" available -j \
  | python3 -c "
import sys, json
data = json.load(sys.stdin)
for devs in data.get('devices', {}).values():
    for d in devs:
        if d['name'] == '$DEVICE_NAME' and d.get('isAvailable'):
            print(d['udid'])
            sys.exit(0)
sys.exit(1)
" 2>/dev/null) || {
  echo "ERROR: $DEVICE_NAME simulator not installed."
  exit 1
}
echo "Using $DEVICE_NAME ($UDID)"

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

# -- Shots ----------------------------------------------------------

SHOTS=(
  "01_browse_right_now"
  "02_forecast_week"
  "03_activity_library"
  "04_add_activity"
  "05_activity_detail"
  "06_theme_rainy"
  "07_theme_night"
  "08_onboarding"
)

export SCREENSHOT_UDID="$UDID"
export SCREENSHOT_DIR="$OUT"

for shot_name in "${SHOTS[@]}"; do
  # Extract the two-digit shot ID (01, 02, ...)
  shot_id="${shot_name:0:2}"
  echo ""
  echo "--- Shot $shot_name ---"
  export SHOT="$shot_name"

  flutter drive \
    --driver=test_driver/screenshot_driver.dart \
    --target=integration_test/screenshot_test.dart \
    --device-id "$UDID" \
    --dart-define="SHOT=$shot_id" \
    --no-pub \
    2>&1 | tail -20

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
