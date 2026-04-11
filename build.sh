#!/bin/bash
# Build-Script für dkd Sprint Tracker
# Voraussetzung: Xcode Command Line Tools installiert
#
# Usage:
#   ./build.sh                — Build only (unsigned)
#   ./build.sh --sign         — Build + Code Sign + Notarize
#   ./build.sh --sign --dmg   — Build + Code Sign + Notarize + DMG erstellen
#
# Für --sign werden benötigt:
#   DEVELOPER_ID   — "Developer ID Application: Name (TEAM_ID)" Zertifikat in Keychain
#   APPLE_ID       — Apple ID E-Mail
#   TEAM_ID        — Apple Developer Team ID
#   APP_PASSWORD   — App-spezifisches Passwort (appleid.apple.com → App-Specific Passwords)

set -e

SIGN=false
DMG=false
for arg in "$@"; do
    case "$arg" in
        --sign) SIGN=true ;;
        --dmg)  DMG=true ;;
    esac
done

if [[ "$SIGN" == true ]]; then
    # .env laden falls vorhanden
    if [[ -f .env ]]; then
        set -a; source .env; set +a
    fi
    : "${DEVELOPER_ID:?Setze DEVELOPER_ID, z.B. export DEVELOPER_ID=\"Developer ID Application: Max Mustermann (ABC123)\"}"
    : "${APPLE_ID:?Setze APPLE_ID, z.B. export APPLE_ID=\"max@example.com\"}"
    : "${TEAM_ID:?Setze TEAM_ID, z.B. export TEAM_ID=\"ABC123\"}"
    : "${APP_PASSWORD:?Setze APP_PASSWORD (App-spezifisches Passwort von appleid.apple.com)}"
fi

if [[ "$DMG" == true && "$SIGN" != true ]]; then
    echo "⚠️  --dmg erfordert --sign (unsignierte DMGs machen keinen Sinn)"
    exit 1
fi

echo "🏗️  Building dkd Sprint Tracker..."

# Universal Binary (arm64 + x86_64)
swiftc -o DkdSprintTracker-arm64 \
    -framework Cocoa \
    -framework ServiceManagement \
    -target arm64-apple-macos13 \
    DkdSprintTracker.swift

swiftc -o DkdSprintTracker-x86_64 \
    -framework Cocoa \
    -framework ServiceManagement \
    -target x86_64-apple-macos13 \
    DkdSprintTracker.swift

lipo -create -output DkdSprintTracker DkdSprintTracker-arm64 DkdSprintTracker-x86_64
rm DkdSprintTracker-arm64 DkdSprintTracker-x86_64

echo "✅ Universal Binary erstellt (Apple Silicon + Intel)"

# App-Icon generieren
echo "🎨 Generating app icon..."
swiftc -o generate_icon -framework Cocoa generate_icon.swift
./generate_icon
iconutil -c icns AppIcon.iconset -o AppIcon.icns
rm -rf AppIcon.iconset generate_icon
echo "✅ App-Icon erstellt"

# App-Bundle erstellen
APP_NAME="dkd Sprint Tracker.app"
rm -rf "$APP_NAME"
mkdir -p "$APP_NAME/Contents/MacOS"
mkdir -p "$APP_NAME/Contents/Resources"

cp DkdSprintTracker "$APP_NAME/Contents/MacOS/"
cp AppIcon.icns "$APP_NAME/Contents/Resources/"

cat > "$APP_NAME/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>dkd Sprint Tracker</string>
    <key>CFBundleDisplayName</key>
    <string>dkd Sprint Tracker</string>
    <key>CFBundleIdentifier</key>
    <string>de.dkd.sprint-tracker</string>
    <key>CFBundleVersion</key>
    <string>1.3.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.3.0</string>
    <key>CFBundleExecutable</key>
    <string>DkdSprintTracker</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# Code Signing + Notarization
if [[ "$SIGN" == true ]]; then
    echo "🔏 Signing with Developer ID..."
    codesign --force --options runtime --sign "$DEVELOPER_ID" "$APP_NAME"
    codesign --verify --deep --strict "$APP_NAME"
    echo "✅ Code Signing erfolgreich"

    echo "📤 Notarization bei Apple einreichen..."
    ditto -c -k --keepParent "$APP_NAME" "/tmp/dkd-notarize.zip"
    xcrun notarytool submit "/tmp/dkd-notarize.zip" \
        --apple-id "$APPLE_ID" \
        --team-id "$TEAM_ID" \
        --password "$APP_PASSWORD" \
        --wait
    rm -f "/tmp/dkd-notarize.zip"
    echo "✅ Notarization erfolgreich"

    echo "📎 Stapling Notarization-Ticket..."
    xcrun stapler staple "$APP_NAME"
    echo "✅ Staple erfolgreich"
else
    # Ohne Signing: Quarantäne-Attribute entfernen
    xattr -c "$APP_NAME" 2>/dev/null || true
fi

echo "📦 App-Bundle erstellt: $APP_NAME"

# DMG erstellen
if [[ "$DMG" == true ]]; then
    VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_NAME/Contents/Info.plist")
    DMG_FILE="DkdSprintTracker-${VERSION}.dmg"
    echo ""
    echo "💿 DMG erstellen..."
    TEMP_DMG=$(mktemp -d)
    cp -R "$APP_NAME" "$TEMP_DMG/"
    ln -s /Applications "$TEMP_DMG/Applications"
    hdiutil create -volname "dkd Sprint Tracker" -srcfolder "$TEMP_DMG" -ov -format UDZO "$DMG_FILE"
    rm -rf "$TEMP_DMG"
    echo "✅ DMG erstellt: $DMG_FILE ($(du -h "$DMG_FILE" | cut -f1 | xargs))"
fi

echo ""
if [[ "$SIGN" == true ]]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ App ist signiert und notarisiert!"
    echo ""
    echo "Installation:"
    echo "  cp -r '$APP_NAME' /Applications/"
    echo ""
    echo "Starten:"
    echo "  open '/Applications/$APP_NAME'"
    if [[ "$DMG" == true ]]; then
        echo ""
        echo "DMG für Kollegen:"
        echo "  $DMG_FILE"
    fi
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
else
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Installation:"
    echo "  cp -r '$APP_NAME' /Applications/"
    echo "  xattr -c '/Applications/$APP_NAME'"
    echo ""
    echo "Starten:"
    echo "  open '/Applications/$APP_NAME'"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "⚠️  Falls die App TROTZDEM nicht öffnet:"
    echo ""
    echo "  1. Rechtsklick auf die App → 'Öffnen' → 'Öffnen' bestätigen"
    echo ""
    echo "  2. Oder: Systemeinstellungen → Datenschutz & Sicherheit"
    echo "     → 'Trotzdem öffnen' klicken"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi
