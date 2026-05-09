# Clipy Modernization Plan

This document covers three workstreams to bring Clipy from its 2020-era state (Xcode 12.2, Swift 5.3, Intel-only) to a modern macOS project. They must be done in order — each phase unlocks the next.

---

## Phase 1: Tooling & Build System (start here)

This phase is the foundation. You cannot compile for Apple Silicon or modernize the code until the build system and dependencies are current.

### 1.1 Raise the deployment target

Current: macOS 10.10 (Yosemite, 2014).
Target: **macOS 13.0 (Ventura)** at minimum.

This is the single most impactful change. macOS 13+ unlocks:
- `SMAppService` (replaces the archived LoginServiceKit)
- Combine (replaces RxSwift/RxCocoa)
- Modern Swift concurrency (async/await)
- Current Sparkle 2.x requirements
- Reasonable Realm compatibility

If you're willing to go to **macOS 14.0 (Sonoma)**, you also unlock SwiftData as a potential Realm replacement.

### 1.2 Update Xcode and Swift

Current: Xcode 12.2 / Swift 5.3.
Target: **Xcode 16+ / Swift 5.10+** (or Swift 6 with strict concurrency).

Update the `DEVELOPER_DIR` in `.github/workflows/CI.yml` to match the new Xcode, and update the runner from `macos-10.15` to `macos-14` or `macos-15`.

### 1.3 Migrate from CocoaPods to Swift Package Manager

Every dependency except LetsMove supports SPM. CocoaPods is effectively in maintenance mode — SPM is Apple's supported solution.

Steps:
1. Add each dependency as a Swift Package in Xcode (File → Add Package Dependencies)
2. Remove `Podfile`, `Podfile.lock`, `Gemfile` references to `cocoapods`
3. Delete the `Pods/` directory reference
4. Switch from `Clipy.xcworkspace` back to `Clipy.xcodeproj`

### 1.4 Move build tools out of CocoaPods

SwiftLint, SwiftGen, and BartyCrouch are currently installed as pods. Build tools should not be framework dependencies.

| Tool | Current | Modern approach |
|------|---------|-----------------|
| **SwiftLint** | Pod 0.40.3 | Homebrew (`brew install swiftlint`) or SPM build plugin. Latest: 0.63+ |
| **SwiftGen** | Pod 6.4.0 | Homebrew (`brew install swiftgen`). Latest: 6.6+ |
| **BartyCrouch** | Pod 3.13.0 | Homebrew (`brew install bartycrouch`). Latest: 4.15+ |

Update Xcode build phases to reference the Homebrew-installed binaries instead of `./Pods/*/` paths. Update the `Dangerfile` SwiftLint binary path.

### 1.5 Update/replace dependencies

| Dependency | Current | Action |
|-----------|---------|--------|
| **RealmSwift** | 10.7.2 | Upgrade to 20.x (major API changes), or replace with SwiftData/GRDB |
| **Sparkle** | 1.26.0 | Upgrade to 2.9+ — new API (`SPUStandardUpdaterController` replaces `SUUpdater`), required for security fixes |
| **RxSwift/RxCocoa** | 5.1.1 | Replace with **Combine** (native, no dependency) |
| **RxScreeen** | 2.0.0 | Replace with **Screeen** (2.1+) wrapped in Combine publishers |
| **LoginServiceKit** | 2.2.0 | **Archived/dead.** Replace with `SMAppService.mainApp.register()` (macOS 13+) |
| **LetsMove** | 1.25 | **Abandoned, no SPM.** Drop entirely or rewrite as a small Swift utility (~50 lines) |
| **SwiftHEXColors** | 1.4.1 | Replace with a trivial `NSColor(hex:)` extension (~20 lines) |
| **Quick/Nimble** | 3.0/9.0 | Upgrade to 7.x/14.x, or migrate to **Swift Testing** (Xcode 16+) |
| **PINCache** | 3.0.3 | Bump to 3.0.4, migrate to SPM. Straightforward. |
| **Sauce** | 2.1.0 | Bump to 2.5.0 (Clipy org, active) |
| **KeyHolder** | 4.0.0 | Bump to 4.2.0 (Clipy org, active) |
| **Magnet** | 3.2.0 | Bump to 3.5.0 (Clipy org, active) |
| **AEXML** | 4.6.0 | Bump to 4.7.0, or replace with Foundation `XMLDocument` |

### 1.6 Eliminate Ruby

After CocoaPods and the pod-based build tools are gone, the only Ruby dependency left is Fastlane (for CI test runs) and Danger (for PR linting).

- **Fastlane**: Replace with direct `xcodebuild test` in the GitHub Actions workflow. Fastlane is overkill for a single test lane.
- **Danger**: Keep if you want automated PR linting, or replace with a SwiftLint GitHub Action.

Once both are gone, delete `Gemfile`, `Gemfile.lock`, and `fastlane/`. No more Ruby.

---

## Phase 2: Apple Silicon / ARM Support

This becomes straightforward once Phase 1 is done, because the updated dependencies all ship arm64 slices.

### 2.1 Set architecture to Universal

In Xcode build settings:
- **Architectures**: `$(ARCHS_STANDARD)` — this produces a Universal Binary (x86_64 + arm64) on modern Xcode
- Remove any `EXCLUDED_ARCHS` or `VALID_ARCHS` overrides if present
- Ensure no build settings force `x86_64` only

### 2.2 Verify all dependencies include arm64

With Phase 1 complete and all packages on current versions via SPM, every dependency supports arm64. There should be no missing slices.

If using any vendored `.framework` or `.a` files, verify with:
```bash
lipo -info <path_to_binary>
# Should show: x86_64 arm64
```

### 2.3 Test on Apple Silicon

Build and run on an M-series Mac natively (not under Rosetta). Specifically test:
- Clipboard monitoring (NSPasteboard polling)
- Hotkey registration (Magnet uses Carbon APIs — these work on arm64 but worth verifying)
- Realm database creation and migration
- Sparkle update checks
- Login item registration

### 2.4 Code signing and notarization

Apple Silicon apps require hardened runtime and notarization for distribution outside the App Store. Ensure:
- Hardened Runtime is enabled in Xcode signing settings
- The app is notarized via `notarytool` (replaces the old `altool`)
- The Developer ID certificate is valid

### 2.5 CI runner update

In `.github/workflows/CI.yml`, use an ARM runner:
```yaml
runs-on: macos-14  # M1-based GitHub Actions runner
```

This ensures CI tests run natively on arm64.

---

## Phase 3: Code Modernization

With the build system current and ARM support working, clean up the Swift code to use modern APIs.

### 3.1 Fix deprecated pasteboard types

The codebase uses `.deprecatedTIFF`, `.deprecatedRTF`, `.deprecatedString`, etc. throughout `CPYClipData.swift` and `MenuManager.swift`. Replace with modern UTType-based pasteboard types:

| Deprecated | Modern replacement |
|-----------|-------------------|
| `.deprecatedString` | `.string` |
| `.deprecatedRTF` | `.rtf` |
| `.deprecatedRTFD` | `.rtfd` |
| `.deprecatedPDF` | `.pdf` |
| `.deprecatedTIFF` | `.tiff` |
| `.deprecatedFilenames` | `.fileURL` |
| `.deprecatedURL` | `.URL` |

### 3.2 Fix deprecated NSCoding / archiving APIs

Multiple files use the deprecated unkeyed archiver:
```swift
// Old (deprecated, insecure)
NSKeyedUnarchiver.unarchiveObject(with: data)
NSKeyedArchiver.archivedData(withRootObject: obj)

// New (secure)
try NSKeyedUnarchiver.unarchivedObject(ofClass: Cls.self, from: data)
try NSKeyedArchiver.archivedData(withRootObject: obj, requiringSecureCoding: true)
```

This affects: `AppEnvironment.swift`, `CPYSnippetsEditorWindowController.swift`, `HotKeyService.swift`, `ClipService.swift`.

Consider migrating `CPYClipData` from `NSCoding` to `Codable` entirely.

### 3.3 Replace RxSwift with Combine

This is the largest code change but eliminates three dependencies (RxSwift, RxCocoa, RxScreeen). Key patterns to convert:

| RxSwift | Combine |
|---------|---------|
| `Observable` | `AnyPublisher` / `Published` |
| `BehaviorRelay` | `CurrentValueSubject` / `@Published` |
| `DisposeBag` | `Set<AnyCancellable>` |
| `subscribe(onNext:)` | `.sink { }` |
| `Observable.interval` | `Timer.publish(every:on:in:)` |
| `defaults.rx.observe()` | `defaults.publisher(for:)` (via KVO) |

### 3.4 Modernize the login item flow

Replace `LoginServiceKit` with:
```swift
import ServiceManagement

try SMAppService.mainApp.register()   // add to login items
try SMAppService.mainApp.unregister() // remove
```

Delete all code in `AppDelegate` that references `LoginServiceKit` and the custom login item prompting logic.

### 3.5 Update Sparkle integration

Sparkle 2.x replaces `SUUpdater.shared()` with `SPUStandardUpdaterController`. The migration is documented in Sparkle's official migration guide. Key change: the updater is now typically instantiated in the XIB or in `applicationDidFinishLaunching` as a retained controller.

### 3.6 Optional: consider SwiftUI for new views

The existing preference panels and snippet editor use XIBs + AppKit. There's no need to rewrite them, but any **new** UI should use SwiftUI. SwiftUI views can be hosted in AppKit windows via `NSHostingController`.

---

## Recommended Order

**Start with Phase 1.** Everything else depends on it. Within Phase 1, the sequence is:

1. Raise deployment target to macOS 13+ and update Xcode/Swift version
2. Move build tools (SwiftLint, SwiftGen, BartyCrouch) to Homebrew
3. Migrate from CocoaPods to SPM, updating dependency versions
4. Replace dead dependencies (LoginServiceKit, LetsMove, SwiftHEXColors)
5. Upgrade Sparkle to 2.x
6. Replace Fastlane/Danger with direct CI commands, delete Ruby

Phase 2 (ARM) should "just work" once Phase 1 is complete — it's mostly verification.

Phase 3 (code modernization) can be done incrementally, file by file, after Phases 1 and 2 are shipping.

---

## Cost/Risk Summary

| Phase | Effort | Risk | Payoff |
|-------|--------|------|--------|
| Phase 1: Tooling | High (1-2 weeks) | Medium — dependency upgrades may break things | Unlocks everything else |
| Phase 2: ARM | Low (1-2 days) | Low — mostly verification | App runs natively on M-series |
| Phase 3: Code | Medium (1-2 weeks) | Low — incremental, testable | Clean modern codebase, fewer dependencies |
