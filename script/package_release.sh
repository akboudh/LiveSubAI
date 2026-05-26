#!/usr/bin/env bash
set -euo pipefail

APP_NAME="LiveSubAI"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
BUNDLE_PATH="$DIST_DIR/$APP_NAME.app"
ZIP_PATH="$ROOT_DIR/${APP_NAME}-macOS-arm64.zip"
CHECKSUM_PATH="$ROOT_DIR/${APP_NAME}-macOS-arm64.zip.sha256"

"$ROOT_DIR/script/build_and_run.sh" --verify

if [[ ! -d "$BUNDLE_PATH" ]]; then
  echo "Missing app bundle: $BUNDLE_PATH" >&2
  exit 66
fi

/bin/rm -f "$ZIP_PATH" "$CHECKSUM_PATH"
cd "$DIST_DIR"
/usr/bin/ditto -c -k --keepParent "$APP_NAME.app" "$ZIP_PATH"
cd "$ROOT_DIR"
/usr/bin/shasum -a 256 "$ZIP_PATH" | /usr/bin/tee "$CHECKSUM_PATH"

echo "Created $ZIP_PATH"
echo "Created $CHECKSUM_PATH"
