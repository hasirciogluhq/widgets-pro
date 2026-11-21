#!/usr/bin/env bash
# Build WidgetsPro.app (menu bar app + WidgetKit extension) with only the Command Line Tools.
# Usage: ./build.sh [debug|release]   Signing: set SIGN_ID (default: ad-hoc "-").
set -euo pipefail
cd "$(dirname "$0")"
CONF=${1:-release}; OPT=$([ "$CONF" = debug ] && echo -Onone || echo -O)
SIGN_ID=${SIGN_ID:--}
TEAM=${TEAM_ID:-}
VERSION=0.1.0
ARCH=$(uname -m); TARGET=$ARCH-apple-macos14.0
OUT=build/$CONF; APP=$OUT/WidgetsPro.app; EXT=$APP/Contents/PlugIns/WidgetsProWidget.appex
GROUP=${TEAM:+$TEAM.}io.github.hasirciogluhq.widgetspro
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS" "$EXT/Contents/MacOS"

swiftc $OPT -target $TARGET -parse-as-library Shared/*.swift App/*.swift \
  -o "$APP/Contents/MacOS/WidgetsPro"
swiftc $OPT -target $TARGET -parse-as-library -application-extension Shared/*.swift Widget/*.swift \
  -Xlinker -e -Xlinker _NSExtensionMain -o "$EXT/Contents/MacOS/WidgetsProWidget"

plist() { # $1 path, $2 exec, $3 bundle id, $4 extra xml
cat > "$1" <<XML
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>$2</string>
<key>CFBundleIdentifier</key><string>$3</string>
<key>CFBundleName</key><string>$2</string>
<key>CFBundleDisplayName</key><string>Widgets Pro</string>
<key>CFBundleShortVersionString</key><string>$VERSION</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>AppGroupID</key><string>$GROUP</string>
$4
</dict></plist>
XML
}
plist "$APP/Contents/Info.plist" WidgetsPro io.github.hasirciogluhq.widgetspro \
  "<key>CFBundlePackageType</key><string>APPL</string><key>LSUIElement</key><true/>"
plist "$EXT/Contents/Info.plist" WidgetsProWidget io.github.hasirciogluhq.widgetspro.widget \
  "<key>CFBundlePackageType</key><string>XPC!</string><key>NSExtension</key><dict><key>NSExtensionPointIdentifier</key><string>com.apple.widgetkit-extension</string></dict>"

ent() { cat > "$1" <<XML
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>$2
<key>com.apple.security.application-groups</key><array><string>$GROUP</string></array>
</dict></plist>
XML
}
ent $OUT/widget.entitlements "<key>com.apple.security.app-sandbox</key><true/>"
ent $OUT/app.entitlements ""
codesign --force --options runtime --sign "$SIGN_ID" --entitlements $OUT/widget.entitlements "$EXT"
codesign --force --options runtime --sign "$SIGN_ID" --entitlements $OUT/app.entitlements "$APP"
echo "Built $APP"
