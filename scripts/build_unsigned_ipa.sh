#!/usr/bin/env bash

set -euo pipefail

APP_SCHEME="PixiaBills"
APP_NAME="PixiaBills"
BUILD_DIR="build"
ARCHIVE_PATH="$BUILD_DIR/$APP_NAME.xcarchive"
PAYLOAD_DIR="$BUILD_DIR/Payload"
VERSION="${1:-0.1.0}"
OUT_IPA="pixia-bills-${VERSION}.ipa"

mkdir -p "$BUILD_DIR"

echo "[1/3] xcodegen generate"
xcodegen generate

echo "[2/3] xcodebuild archive"
xcodebuild \
  -project "$APP_NAME.xcodeproj" \
  -scheme "$APP_SCHEME" \
  -configuration Release \
  -sdk iphoneos \
  -archivePath "$ARCHIVE_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  MARKETING_VERSION="$VERSION" \
  INFOPLIST_KEY_CFBundleShortVersionString="$VERSION" \
  archive

echo "[3/3] package unsigned ipa"
APP_PATH="$ARCHIVE_PATH/Products/Applications/$APP_NAME.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "Archived app not found at: $APP_PATH"
  exit 1
fi

rm -rf "$PAYLOAD_DIR"
mkdir -p "$PAYLOAD_DIR"
cp -R "$APP_PATH" "$PAYLOAD_DIR/"

(
  cd "$BUILD_DIR"
  rm -f "$OUT_IPA"
  zip -qry "$OUT_IPA" Payload
)

rm -rf "$PAYLOAD_DIR"

echo "Generated: $BUILD_DIR/$OUT_IPA"
