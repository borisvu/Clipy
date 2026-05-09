# Phase 1: Tooling & Build System Modernization — Design Spec

## Goal

Migrate Clipy from its 2020-era build system (Xcode 12.2, CocoaPods, Ruby tooling, macOS 10.10 target) to a modern Swift project (Xcode 16+, Swift Package Manager, macOS 14 target) while keeping the app functionally identical.

## Decisions

- **Deployment target:** macOS 14.0 (Sonoma)
- **Xcode / Swift:** Xcode 16+ / Swift 5.10+
- **Package manager:** Swift Package Manager (replacing CocoaPods)
- **Database:** RealmSwift, upgraded from 10.7.2 to 20.x
- **Reactive framework:** RxSwift/RxCocoa, upgraded from 5.1.1 to 6.x (Combine migration deferred to Phase 3)
- **Testing:** Swift Testing (replacing Quick 3.0 / Nimble 9.0)
- **Build tools:** Homebrew-installed (replacing pod-based SwiftLint, SwiftGen, BartyCrouch)
- **CI:** Direct xcodebuild in GitHub Actions on macos-14 runner (replacing Fastlane/Ruby)

## Dependency Actions

### Upgrade via SPM

| Package | From | To | Notes |
|---------|------|----|-------|
| RealmSwift | 10.7.2 | 20.x | Major version — API changes in Realm configuration, migration block syntax |
| RxSwift | 5.1.1 | 6.x | RxRelay bundled separately in 6.x, some API renames |
| RxCocoa | 5.1.1 | 6.x | Ships with RxSwift |
| RxScreeen | 2.0.0 | 2.2.0 | Clipy org, minor bump |
| Sparkle | 1.26.0 | 2.9.x | Major version — `SUUpdater` replaced by `SPUStandardUpdaterController` |
| Sauce | 2.1.0 | 2.5.0 | Clipy org, minor bump |
| KeyHolder | 4.0.0 | 4.2.0 | Clipy org, minor bump |
| Magnet | 3.2.0 | 3.5.0 | Clipy org, minor bump |
| PINCache | 3.0.3 | 3.0.4 | Patch bump |
| AEXML | 4.6.0 | 4.7.0 | Minor bump |

### Delete and replace

| Package | Replacement |
|---------|-------------|
| LoginServiceKit (archived) | `SMAppService.mainApp.register()` / `.unregister()` (ServiceManagement framework, macOS 13+) |
| LetsMove (abandoned, no SPM) | Drop entirely, or replace with a ~50-line Swift utility using `NSWorkspace` |
| SwiftHEXColors | Inline `NSColor(hex:)` extension (~20 lines) |
| Quick 3.0 | Swift Testing (`@Test`, `#expect`) |
| Nimble 9.0 | Swift Testing (`#expect`) |

### Move to Homebrew

| Tool | From (pod) | To |
|------|-----------|-----|
| SwiftLint | 0.40.3 | `brew install swiftlint` (0.63+), update Xcode build phase script |
| SwiftGen | 6.4.0 | `brew install swiftgen` (6.6+), no code changes |
| BartyCrouch | 3.13.0 | `brew install bartycrouch` (4.15+) |

### Delete entirely

| Item | Notes |
|------|-------|
| CocoaPods | Delete `Podfile`, `Podfile.lock`; project no longer needs `.xcworkspace` |
| Fastlane | Replace test lane with `xcodebuild test` in GitHub Actions |
| Danger | Replace with SwiftLint GitHub Action or drop |
| Ruby (Gemfile, Gemfile.lock) | All Ruby consumers eliminated above |

## Code Changes

### Sparkle 2.x migration

Replace in `AppDelegate.swift`:
```swift
// Old (Sparkle 1.x)
let updater = SUUpdater.shared()
updater?.feedURL = Constants.Application.appcastURL
updater?.automaticallyChecksForUpdates = ...
updater?.updateCheckInterval = ...

// New (Sparkle 2.x)
// SPUStandardUpdaterController instantiated as a property or via XIB
// Configuration handled through SPUUpdaterDelegate or Info.plist keys
```

### LoginServiceKit replacement

Replace in `AppDelegate.swift`:
```swift
// Old
import LoginServiceKit
LoginServiceKit.addLoginItems(at: appPath)
LoginServiceKit.removeLoginItems(at: appPath)

// New
import ServiceManagement
try SMAppService.mainApp.register()
try SMAppService.mainApp.unregister()
```

### SwiftHEXColors replacement

Replace `import SwiftHEXColors` in `CPYClipData.swift` with an inline `NSColor` extension:
```swift
extension NSColor {
    convenience init?(hex: String) {
        // ~20 lines: parse hex string, extract r/g/b/a, init
    }
}
```

### LetsMove replacement

Remove `PFMoveToApplicationsFolderIfNecessary()` call from `applicationWillFinishLaunching` in `AppDelegate.swift`. Either drop the feature or replace with a simple check using `Bundle.main.bundlePath` and `NSWorkspace`.

### Test migration

Rewrite four test files from Quick/Nimble DSL to Swift Testing:
- `FolderSpec.swift` → `FolderTests.swift`
- `SnippetSpec.swift` → `SnippetTests.swift`
- `DraggedDataSpec.swift` → `DraggedDataTests.swift`
- `HotKeyServiceSpec.swift` → `HotKeyServiceTests.swift`

Pattern: `describe/it/expect(x).to(equal(y))` → `@Test func / #expect(x == y)`

### Realm migration

Update `Realm+Migration.swift`:
- Bump schema version from 7 to 8
- Update migration block syntax for Realm 20.x API
- Update `Realm.Configuration` initialization

### RxSwift 6.x migration

Mechanical changes across the codebase:
- `import RxRelay` added where `BehaviorRelay` is used (now a separate module in Rx 6)
- Minor API renames as needed

### CI workflow

Replace `.github/workflows/CI.yml`:
```yaml
runs-on: macos-14
steps:
  - uses: actions/checkout@v4
  - name: Select Xcode
    run: sudo xcode-select -s /Applications/Xcode_16.app
  - name: Resolve packages
    run: xcodebuild -resolvePackageDependencies -project Clipy.xcodeproj -scheme Clipy
  - name: Test
    run: xcodebuild test -project Clipy.xcodeproj -scheme Clipy -destination 'platform=macOS'
```

Replace or delete `.github/workflows/Danger.yml`.

### Build phase updates

Update Xcode build phase scripts:
- SwiftLint: change from `"${PODS_ROOT}/SwiftLint/swiftlint"` to `swiftlint` (Homebrew path)
- SwiftGen: change from pods path to `swiftgen` (Homebrew path)

### File deletions

- `Podfile`
- `Podfile.lock`
- `Gemfile`
- `Gemfile.lock`
- `Dangerfile`
- `fastlane/` directory
- `Clipy.xcworkspace/` (CocoaPods-generated; project returns to `.xcodeproj` only)

## Out of scope

- RxSwift → Combine migration (Phase 3)
- Deprecated pasteboard type updates (Phase 3)
- Deprecated NSCoding/archiver API updates (Phase 3)
- SwiftUI adoption (Phase 3)
- Apple Silicon verification (Phase 2, but should "just work" after Phase 1)

## Risk areas

1. **Realm 10→20 migration** — largest version jump. Schema migration block syntax and configuration APIs have changed. Existing user databases must migrate cleanly.
2. **Sparkle 1→2** — different architecture (delegate-based vs shared singleton). Requires careful testing of the update flow.
3. **Xcode project file surgery** — removing CocoaPods integration and adding SPM packages modifies the `.xcodeproj` extensively. Best done through Xcode's UI, not manual pbxproj editing.
