#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="${PROJECT_PATH:-$ROOT_DIR/ChezmoiSyncMonitor.xcodeproj}"
SCHEME="${SCHEME:-ChezmoiSyncMonitor}"
CONFIGURATION="${CONFIGURATION:-Release}"
APP_NAME="${APP_NAME:-Chezmoi Sync Monitor}"
TEAM_ID="${TEAM_ID:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
DEVELOPER_ID_APP_CERT="${DEVELOPER_ID_APP_CERT:-Developer ID Application}"
BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/build/release}"
ARCHIVE_PATH="$BUILD_DIR/${SCHEME}.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
ARTIFACTS_DIR="$BUILD_DIR/artifacts"
EXPORT_OPTIONS_PLIST="$BUILD_DIR/exportOptions.plist"
APP_PATH="$EXPORT_DIR/${APP_NAME}.app"
ZIP_PATH="$ARTIFACTS_DIR/${APP_NAME}.zip"
DMG_PATH="$ARTIFACTS_DIR/${APP_NAME}.dmg"

if [[ -z "$TEAM_ID" || -z "$NOTARY_PROFILE" ]]; then
  cat <<USAGE
Missing required environment values.

Usage:
  TEAM_ID=<APPLE_TEAM_ID> NOTARY_PROFILE=<NOTARY_KEYCHAIN_PROFILE> ./scripts/release.sh

Optional:
  DEVELOPER_ID_APP_CERT="Developer ID Application"
  BUILD_DIR=build/release
  SCHEME=ChezmoiSyncMonitor
USAGE
  exit 1
fi

for cmd in xcodebuild xcrun hdiutil ditto; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
done

IDENTITIES_OUTPUT="$(security find-identity -v -p codesigning 2>&1 || true)"
MATCHING_IDENTITY="$(
  echo "$IDENTITIES_OUTPUT" | awk \
    -v cert="$DEVELOPER_ID_APP_CERT" \
    -v team="($TEAM_ID)" \
    'index($0, cert) && index($0, team) { print; exit }'
)"

if [[ -z "$MATCHING_IDENTITY" ]]; then
  echo "Missing signing identity: '$DEVELOPER_ID_APP_CERT' for team '$TEAM_ID'." >&2
  echo >&2
  echo "Expected to find a certificate like:" >&2
  echo "  $DEVELOPER_ID_APP_CERT: <Your Name> ($TEAM_ID)" >&2
  echo >&2
  echo "Current codesigning identities:" >&2
  echo "$IDENTITIES_OUTPUT" >&2
  echo >&2
  echo "Fix:" >&2
  echo "  1) Install a Developer ID Application certificate (with private key) in your login keychain." >&2
  echo "  2) Verify with: security find-identity -v -p codesigning" >&2
  exit 1
fi

set +e
NOTARY_CHECK_OUTPUT="$(xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" 2>&1 >/dev/null)"
NOTARY_CHECK_STATUS=$?
set -e

if [[ $NOTARY_CHECK_STATUS -ne 0 ]]; then
  echo "Notary profile '$NOTARY_PROFILE' is not usable." >&2
  echo >&2
  echo "notarytool returned:" >&2
  echo "$NOTARY_CHECK_OUTPUT" >&2
  echo >&2
  echo "Fix:" >&2
  echo "  xcrun notarytool store-credentials \"$NOTARY_PROFILE\" \\" >&2
  echo "    --apple-id \"<APPLE_ID>\" \\" >&2
  echo "    --team-id \"$TEAM_ID\" \\" >&2
  echo "    --password \"<APP_SPECIFIC_PASSWORD>\"" >&2
  echo >&2
  echo "Then verify with:" >&2
  echo "  xcrun notarytool history --keychain-profile \"$NOTARY_PROFILE\"" >&2
  exit 1
fi

mkdir -p "$BUILD_DIR" "$EXPORT_DIR" "$ARTIFACTS_DIR"
rm -rf "$ARCHIVE_PATH" "$EXPORT_DIR" "$ZIP_PATH" "$DMG_PATH"

cat > "$EXPORT_OPTIONS_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>developer-id</string>
  <key>signingStyle</key>
  <string>manual</string>
  <key>signingCertificate</key>
  <string>${DEVELOPER_ID_APP_CERT}</string>
  <key>stripSwiftSymbols</key>
  <true/>
  <key>teamID</key>
  <string>${TEAM_ID}</string>
</dict>
</plist>
PLIST

echo "[1/6] Archiving ${SCHEME}"
xcodebuild archive \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -archivePath "$ARCHIVE_PATH" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$DEVELOPER_ID_APP_CERT" \
  DEVELOPMENT_TEAM="$TEAM_ID"

echo "[2/6] Exporting signed app"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Exported app not found at: $APP_PATH" >&2
  exit 1
fi

echo "[3/6] Creating ZIP artifact"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo "[4/6] Creating DMG artifact"
DMG_STAGING="$BUILD_DIR/dmg-staging"
TEMP_DMG_PATH="$BUILD_DIR/${SCHEME}-temp.dmg"
DMG_MOUNT="$BUILD_DIR/dmg-mount"
APP_ICON_ICNS="$APP_PATH/Contents/Resources/AppIcon.icns"
rm -rf "$DMG_STAGING" "$TEMP_DMG_PATH" "$DMG_MOUNT"
mkdir -p "$DMG_STAGING"
cp -R "$APP_PATH" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_STAGING" \
  -ov \
  -format UDRW \
  "$TEMP_DMG_PATH" >/dev/null

if [[ -f "$APP_ICON_ICNS" ]] && command -v SetFile >/dev/null 2>&1; then
  mkdir -p "$DMG_MOUNT"
  ATTACH_OUTPUT="$(hdiutil attach "$TEMP_DMG_PATH" -readwrite -noverify -noautoopen -mountpoint "$DMG_MOUNT")"
  DMG_DEVICE="$(echo "$ATTACH_OUTPUT" | awk 'NR==1 {print $1}')"

  cp "$APP_ICON_ICNS" "$DMG_MOUNT/.VolumeIcon.icns"
  SetFile -a V "$DMG_MOUNT/.VolumeIcon.icns"
  SetFile -a C "$DMG_MOUNT"
  hdiutil detach "$DMG_DEVICE" >/dev/null
else
  echo "Warning: App icon or SetFile not found; DMG will use default volume icon." >&2
fi

hdiutil convert "$TEMP_DMG_PATH" -format UDZO -o "$DMG_PATH" -ov >/dev/null
rm -rf "$DMG_STAGING" "$TEMP_DMG_PATH" "$DMG_MOUNT"

echo "[5/6] Submitting DMG for notarization"
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait

echo "[6/6] Stapling notarization ticket"
xcrun stapler staple -v "$DMG_PATH"

echo "Release ready:"
echo "  - App: $APP_PATH"
echo "  - Zip: $ZIP_PATH"
echo "  - DMG: $DMG_PATH"
