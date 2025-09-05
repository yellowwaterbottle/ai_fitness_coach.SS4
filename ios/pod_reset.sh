#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"/..
flutter clean
rm -rf ios/Pods ios/Podfile.lock ios/Runner.xcworkspace
cd ios
pod repo update
pod install
cd ..
flutter pub get
echo "Done. Open ios/Runner.xcworkspace and Clean Build Folder in Xcode."



