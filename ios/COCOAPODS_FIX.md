# Fix "No such module 'Flutter' / 'Flutter/Flutter.h' not found"

1) Close Xcode.
2) From repo root, run:

```bash
cd ios
rm -rf Pods Podfile.lock Runner.xcworkspace
pod repo update
pod install
cd ..
flutter clean
flutter pub get
open ios/Runner.xcworkspace
```

3. In Xcode: Product → **Clean Build Folder** (⇧⌘K) → Run (⌘R).

If still failing, also delete DerivedData:

```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/*
```

**Always open `Runner.xcworkspace` (not `Runner.xcodeproj`).**



