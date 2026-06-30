#!/usr/bin/env bash
# Build, sign (Developer ID + hardened runtime), and notarize resumemaxx.app.
#
# Because the app bundles only the small sidecar source (the Node runtime is
# installed into Application Support at first run), there are no third-party
# binaries inside the bundle to sign, so this is a normal app notarization.
#
# Prerequisites (one-time):
#   - An Apple Developer account and a "Developer ID Application" certificate
#     installed in your login keychain.
#   - A stored notarytool credential profile:
#       xcrun notarytool store-credentials resumemaxx-notary \
#         --apple-id you@example.com --team-id TEAMID --password APP_SPECIFIC_PW
#
# Then set these env vars and run this script:
#   SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
#   NOTARY_PROFILE="resumemaxx-notary"
set -euo pipefail

: "${SIGN_IDENTITY:?set SIGN_IDENTITY to your Developer ID Application identity}"
: "${NOTARY_PROFILE:?set NOTARY_PROFILE to your notarytool keychain profile}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> Ensuring sidecar source deps resolve (for the bundled package-lock)"
( cd sidecar && npm install --omit=dev --no-audit --no-fund --legacy-peer-deps >/dev/null )

echo "==> Generating project"
xcodegen generate

BUILD="$ROOT/.build_release"
echo "==> Building Release"
xcodebuild -project resumemaxx.xcodeproj -scheme resumemaxx -configuration Release \
  -derivedDataPath "$BUILD" \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
  OTHER_CODE_SIGN_FLAGS="--timestamp --options runtime" \
  build

APP="$BUILD/Build/Products/Release/resumemaxx.app"
echo "==> Signing $APP"
codesign --force --options runtime --timestamp \
  --entitlements app/resumemaxx.entitlements \
  --sign "$SIGN_IDENTITY" "$APP"
codesign --verify --strict --verbose=2 "$APP"

ZIP="$ROOT/resumemaxx.zip"
echo "==> Zipping for notarization"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "==> Notarizing (waits for Apple)"
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait

echo "==> Stapling"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

echo "==> Done: $APP"
echo "    Distribute the stapled .app (or wrap it in a .dmg)."
