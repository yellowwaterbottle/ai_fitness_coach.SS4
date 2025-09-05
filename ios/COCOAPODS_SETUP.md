# CocoaPods Setup / Fix for bench_mvp (iOS)

**Always open `ios/Runner.xcworkspace`, not `Runner.xcodeproj`.**

If you hit:  
- `Command PhaseScriptExecution failed with a nonzero exit code`  
- `Framework 'Pods_Runner' not found`  
- `Linker command failed with exit code 1`  

Run these steps exactly:

```bash
cd "$(git rev-parse --show-toplevel)"

flutter clean
rm -rf ios/Pods ios/Podfile.lock ios/Runner.xcworkspace

cd ios
pod repo update
pod install
cd ..

flutter pub get
open ios/Runner.xcworkspace
```

Then in Xcode:

1. Product → **Clean Build Folder** (⇧⌘K)
2. Select real iPhone (recommended) or simulator
3. **Run** (⌘R)

**Verify in Runner → Build Phases:**

* `[CP] Check Pods Manifest.lock`
* `[CP] Embed Pods Frameworks`
* `[CP] Copy Pods Resources`
* `Run Script` (Flutter) and `Thin Binary`

If CocoaPods isn't installed or fails on Apple Silicon:

```bash
sudo gem install cocoapods ffi
cd ios && pod install && cd ..
```

If project originated on Windows and shell scripts break (CRLF):

```bash
git config core.autocrlf input
cd ios && rm -rf Pods Podfile.lock Runner.xcworkspace && pod install && cd ..
```



