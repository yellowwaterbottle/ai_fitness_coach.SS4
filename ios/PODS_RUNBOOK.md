# iOS Pods Runbook (Flutter/Flutter.h not found, SwiftEmitModule errors)

1) Close Xcode.
2) From repo root:
```bash
bash ios/pods_reset.sh
open ios/Runner.xcworkspace
```

3. In Xcode: Product → **Clean Build Folder** (⇧⌘K) → **Run** (⌘R).

Verify in Runner → Build Phases:

* [CP] Check Pods Manifest.lock
* [CP] Embed Pods Frameworks
* [CP] Copy Pods Resources
* Run Script (Flutter), Thin Binary

If issues persist, also clear DerivedData:

```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/*
```

Always open **Runner.xcworkspace** (NOT Runner.xcodeproj).
