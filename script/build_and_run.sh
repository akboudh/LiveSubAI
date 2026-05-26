#!/usr/bin/env bash
set -euo pipefail

APP_NAME="LiveSubAI"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
BUNDLE_PATH="$DIST_DIR/$APP_NAME.app"
DERIVED_DATA_PATH="$ROOT_DIR/.build/xcode"
BUILT_APP_PATH="$DERIVED_DATA_PATH/Build/Products/Debug/$APP_NAME.app"

MODE="${1:-}"

if [[ -z "${DEVELOPER_DIR:-}" ]]; then
  if [[ -d "/Applications/Xcode.app/Contents/Developer" ]]; then
    export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
  elif [[ -d "$HOME/Downloads/Xcode.app/Contents/Developer" ]]; then
    export DEVELOPER_DIR="$HOME/Downloads/Xcode.app/Contents/Developer"
  fi
fi

stop_running_app() {
  /usr/bin/pkill -x "$APP_NAME" 2>/dev/null || true
}

build_app() {
  cd "$ROOT_DIR"
  /usr/bin/xcodebuild \
    -project "$ROOT_DIR/LiveSubAI.xcodeproj" \
    -scheme "$APP_NAME" \
    -destination "platform=macOS" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    build
}

stage_bundle() {
  /bin/rm -rf "$BUNDLE_PATH"
  /bin/mkdir -p "$DIST_DIR"
  /usr/bin/ditto "$BUILT_APP_PATH" "$BUNDLE_PATH"
}

launch_app() {
  /usr/bin/open "$BUNDLE_PATH"
}

verify_app() {
  sleep 1
  /usr/bin/pgrep -x "$APP_NAME" >/dev/null
}

stop_running_app
build_app
stage_bundle

case "$MODE" in
  --verify)
    launch_app
    verify_app
    echo "$APP_NAME launched"
    ;;
  --logs)
    launch_app
    /usr/bin/log stream --info --predicate "process == '$APP_NAME'"
    ;;
  --debug)
    /usr/bin/lldb "$BUNDLE_PATH/Contents/MacOS/$APP_NAME"
    ;;
  "")
    launch_app
    ;;
  *)
    echo "Unknown option: $MODE" >&2
    exit 64
    ;;
esac
