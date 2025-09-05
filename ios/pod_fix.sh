#!/usr/bin/env bash
set -euo pipefail
pushd "$(dirname "$0")"/.. >/dev/null
cd ios
rm -rf Pods Podfile.lock Runner.xcworkspace
pod repo update
pod install
popd >/dev/null
flutter clean
flutter pub get
echo "Done. Now open ios/Runner.xcworkspace, Clean Build Folder (⇧⌘K), then Run."



