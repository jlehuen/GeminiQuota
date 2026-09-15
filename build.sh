#!/usr/bin/env bash
set -e

# Dossier racine du projet
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$HOME/Applications/GeminiQuota.app"

echo "🔨 Compilation de GeminiQuota (Swift)..."
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Compilation native macOS avec optimisations
swiftc -parse-as-library -O -target arm64-apple-macos13.0 \
    "$PROJECT_DIR/Sources/main.swift" \
    -o "$APP_DIR/Contents/MacOS/GeminiQuota"

# Copie des ressources
cp "$PROJECT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$PROJECT_DIR/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
cp "$PROJECT_DIR/Sources/main.swift" "$APP_DIR/Contents/Resources/main.swift"
chmod +x "$APP_DIR/Contents/MacOS/GeminiQuota"

echo "✅ Application installée avec succès dans $APP_DIR"

# Redémarrage de l'application si demandé ou actif
if [[ "$1" == "--restart" || -z "$1" ]]; then
    echo "🔄 Redémarrage de GeminiQuota.app..."
    killall GeminiQuota 2>/dev/null || true
    sleep 1
    open "$APP_DIR"
    echo "🚀 GeminiQuota est actif dans la barre des menus !"
fi
