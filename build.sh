#!/bin/bash
# Build-Script für dkd Sprint Tracker
# Voraussetzung: Xcode Command Line Tools installiert

set -e

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
    <string>1.2.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.2.0</string>
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

# Gatekeeper-Quarantäne direkt entfernen
xattr -cr "$APP_NAME" 2>/dev/null || true

echo "📦 App-Bundle erstellt: $APP_NAME"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Installation:"
echo "  cp -r '$APP_NAME' /Applications/"
echo "  xattr -cr '/Applications/$APP_NAME'"
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
