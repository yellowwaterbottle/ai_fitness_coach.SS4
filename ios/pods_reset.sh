#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

flutter clean
flutter pub get
rm -rf ios/Pods ios/Podfile.lock ios/Runner.xcworkspace
cd ios
pod repo update
pod install
cd ..

echo "✅ Pods reset complete. Now open: ios/Runner.xcworkspace"
echo "Then in Xcode: Product → Clean Build Folder (⇧⌘K) → Run (⌘R)"
