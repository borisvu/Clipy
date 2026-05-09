# Phase 1: Tooling & Build System Modernization — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate Clipy from CocoaPods/Ruby/Xcode 12 to SPM/Xcode 16+/macOS 14, upgrading all dependencies while keeping the app functionally identical.

**Architecture:** No architectural changes — this is a build system and dependency version migration. The app's structure (AppEnvironment DI, Realm persistence, Rx bindings, status bar menus) stays the same. We replace dead dependencies with inline code, upgrade live ones, and swap the package manager.

**Tech Stack:** Swift 5.10+, Xcode 16+, macOS 14.0 deployment target, Swift Package Manager, RealmSwift 20.x, RxSwift 6.x, Sparkle 2.x, Swift Testing

---

### Task 1: Replace SwiftHEXColors with inline NSColor extension

The simplest dependency removal. SwiftHEXColors is used in exactly one place: `CPYClipData.swift:82` calls `NSColor(hexString:)`. Replace the import with a self-contained extension.

**Files:**
- Create: `Clipy/Sources/Extensions/NSColor+HexString.swift`
- Modify: `Clipy/Sources/Models/CPYClipData.swift:14,82`

- [ ] **Step 1: Create the NSColor hex extension**

Create `Clipy/Sources/Extensions/NSColor+HexString.swift`:

```swift
import Cocoa

extension NSColor {
    convenience init?(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r, g, b, a: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (r, g, b, a) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17, 255)
        case 6: // RRGGBB (24-bit)
            (r, g, b, a) = (int >> 16, int >> 8 & 0xFF, int & 0xFF, 255)
        case 8: // RRGGBBAA (32-bit)
            (r, g, b, a) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }

        self.init(
            calibratedRed: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}
```

- [ ] **Step 2: Update CPYClipData.swift**

In `Clipy/Sources/Models/CPYClipData.swift`, remove line 14:
```swift
// DELETE this line:
import SwiftHEXColors
```

The call on line 82 (`NSColor(hexString: stringValue)`) stays unchanged — the new extension provides the same initializer signature.

- [ ] **Step 3: Add the new file to the Xcode project**

Open `Clipy.xcodeproj` in Xcode. Drag `Clipy/Sources/Extensions/NSColor+HexString.swift` into the Extensions group in the project navigator. Ensure "Add to target: Clipy" is checked.

- [ ] **Step 4: Build to verify**

Run: `xcodebuild build -workspace Clipy.xcworkspace -scheme Clipy -destination 'platform=macOS' | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add Clipy/Sources/Extensions/NSColor+HexString.swift Clipy/Sources/Models/CPYClipData.swift Clipy.xcodeproj/project.pbxproj
git commit -m "Replace SwiftHEXColors with inline NSColor hex extension"
```

---

### Task 2: Replace LoginServiceKit with SMAppService

LoginServiceKit is archived and wraps deprecated APIs. Replace with Apple's `ServiceManagement` framework (`SMAppService`, available macOS 13+).

**Files:**
- Modify: `Clipy/Sources/AppDelegate.swift:17,154-163`

- [ ] **Step 1: Update imports in AppDelegate.swift**

In `Clipy/Sources/AppDelegate.swift`, replace:
```swift
import LoginServiceKit
```
with:
```swift
import ServiceManagement
```

- [ ] **Step 2: Replace toggleAddingToLoginItems method**

In `Clipy/Sources/AppDelegate.swift`, replace the `toggleAddingToLoginItems` method (lines 154-159):

```swift
// OLD:
private func toggleAddingToLoginItems(_ isEnable: Bool) {
    let appPath = Bundle.main.bundlePath
    LoginServiceKit.removeLoginItems(at: appPath)
    guard isEnable else { return }
    LoginServiceKit.addLoginItems(at: appPath)
}

// NEW:
private func toggleAddingToLoginItems(_ isEnable: Bool) {
    do {
        if isEnable {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    } catch {
        NSLog("Failed to update login item: \(error)")
    }
}
```

- [ ] **Step 3: Build to verify**

Run: `xcodebuild build -workspace Clipy.xcworkspace -scheme Clipy -destination 'platform=macOS' | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Clipy/Sources/AppDelegate.swift
git commit -m "Replace LoginServiceKit with SMAppService for login items"
```

---

### Task 3: Remove LetsMove

LetsMove provides the `PFMoveToApplicationsFolderIfNecessary()` call in `applicationWillFinishLaunching`. It's abandoned with no SPM support. Drop it entirely — the feature is low-value for a developer-distributed app.

**Files:**
- Modify: `Clipy/Sources/AppDelegate.swift:22,204-208`

- [ ] **Step 1: Remove import and usage**

In `Clipy/Sources/AppDelegate.swift`:

Remove the import:
```swift
// DELETE:
import LetsMove
```

Replace `applicationWillFinishLaunching` (lines 204-208):
```swift
// OLD:
func applicationWillFinishLaunching(_ notification: Notification) {
    #if RELEASE
        PFMoveToApplicationsFolderIfNecessary()
    #endif
}

// NEW — remove the entire method (it has no other logic)
```

- [ ] **Step 2: Build to verify**

Run: `xcodebuild build -workspace Clipy.xcworkspace -scheme Clipy -destination 'platform=macOS' | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Clipy/Sources/AppDelegate.swift
git commit -m "Remove LetsMove dependency (drop move-to-Applications prompt)"
```

---

### Task 4: Migrate Sparkle 1.x to 2.x

Sparkle 2.x replaces the singleton `SUUpdater.shared()` with `SPUStandardUpdaterController`. The updater is configured via `Info.plist` keys rather than programmatic property setting.

**Files:**
- Modify: `Clipy/Sources/AppDelegate.swift:14,186-189`
- Modify: `Clipy/Sources/Preferences/Panels/Base.lproj/CPYUpdatesPreferenceViewController.xib:87`
- Modify: `Clipy/Supporting Files/Info.plist` (add Sparkle keys)

- [ ] **Step 1: Add Sparkle Info.plist keys**

Add these keys to `Clipy/Supporting Files/Info.plist`:
```xml
<key>SUFeedURL</key>
<string>https://clipy-app.com/appcast.xml</string>
<key>SUEnableAutomaticChecks</key>
<true/>
```

- [ ] **Step 2: Update AppDelegate.swift**

Replace the Sparkle import:
```swift
// OLD:
import Sparkle

// NEW:
import Sparkle
```
(Import name stays the same.)

Add a property to `AppDelegate`:
```swift
// Add as a property of the AppDelegate class:
let updaterController = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
```

Replace the Sparkle setup in `applicationDidFinishLaunching` (lines 186-189):
```swift
// OLD:
let updater = SUUpdater.shared()
updater?.feedURL = Constants.Application.appcastURL
updater?.automaticallyChecksForUpdates = AppEnvironment.current.defaults.bool(forKey: Constants.Update.enableAutomaticCheck)
updater?.updateCheckInterval = TimeInterval(AppEnvironment.current.defaults.integer(forKey: Constants.Update.checkInterval))

// NEW:
updaterController.updater.automaticallyChecksForUpdates = AppEnvironment.current.defaults.bool(forKey: Constants.Update.enableAutomaticCheck)
updaterController.updater.updateCheckInterval = TimeInterval(AppEnvironment.current.defaults.integer(forKey: Constants.Update.checkInterval))
updaterController.startUpdater()
```

- [ ] **Step 3: Update the Updates preference XIB**

In `Clipy/Sources/Preferences/Panels/Base.lproj/CPYUpdatesPreferenceViewController.xib`, the XIB references `SUUpdater` as a custom class (line 87). This needs to be updated in Interface Builder to use `SPUStandardUpdaterController` or have the bindings reconnected programmatically. Open the XIB in Xcode and update the custom class reference.

- [ ] **Step 4: Remove appcastURL constant**

In `Clipy/Sources/Constants.swift`, the `appcastURL` is now in `Info.plist`. You can keep the constant for reference or remove it — it's no longer used in the Sparkle setup code.

- [ ] **Step 5: Build to verify**

Run: `xcodebuild build -workspace Clipy.xcworkspace -scheme Clipy -destination 'platform=macOS' | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add Clipy/Sources/AppDelegate.swift Clipy/Sources/Constants.swift "Clipy/Supporting Files/Info.plist" "Clipy/Sources/Preferences/Panels/Base.lproj/CPYUpdatesPreferenceViewController.xib" Clipy.xcodeproj/project.pbxproj
git commit -m "Migrate Sparkle 1.x to 2.x (SPUStandardUpdaterController)"
```

---

### Task 5: Add RxRelay import for RxSwift 6.x compatibility

In RxSwift 6, `BehaviorRelay` moved to the `RxRelay` module. Two files use it and need the import added. This is a source-level preparation — the actual package version bump happens during the SPM migration.

**Files:**
- Modify: `Clipy/Sources/Services/ClipService.swift:17-18`
- Modify: `Clipy/Sources/Services/ExcludeAppService.swift:14-15`

- [ ] **Step 1: Add RxRelay import to ClipService.swift**

In `Clipy/Sources/Services/ClipService.swift`, add after the existing Rx imports:
```swift
import RxSwift
import RxCocoa
import RxRelay  // ADD THIS LINE
```

- [ ] **Step 2: Add RxRelay import to ExcludeAppService.swift**

In `Clipy/Sources/Services/ExcludeAppService.swift`, add after the existing Rx imports:
```swift
import RxSwift
import RxCocoa
import RxRelay  // ADD THIS LINE
```

- [ ] **Step 3: Commit**

```bash
git add Clipy/Sources/Services/ClipService.swift Clipy/Sources/Services/ExcludeAppService.swift
git commit -m "Add RxRelay imports for RxSwift 6.x compatibility"
```

---

### Task 6: Migrate tests from Quick/Nimble to Swift Testing

Rewrite all four test files. Swift Testing uses `@Test` functions and `#expect()` macros instead of Quick's `describe/it` DSL and Nimble's `expect().to()` matchers.

**Files:**
- Delete: `ClipyTests/FolderSpec.swift`
- Delete: `ClipyTests/SnippetSpec.swift`
- Delete: `ClipyTests/DraggedDataSpec.swift`
- Delete: `ClipyTests/HotKeyServiceSpec.swift`
- Create: `ClipyTests/FolderTests.swift`
- Create: `ClipyTests/SnippetTests.swift`
- Create: `ClipyTests/DraggedDataTests.swift`
- Create: `ClipyTests/HotKeyServiceTests.swift`

- [ ] **Step 1: Create FolderTests.swift**

Create `ClipyTests/FolderTests.swift`:

```swift
import Testing
import RealmSwift
@testable import Clipy

struct FolderTests {

    private func makeInMemoryRealm() -> Realm {
        let config = Realm.Configuration(inMemoryIdentifier: UUID().uuidString)
        return try! Realm(configuration: config)
    }

    @Test func deepCopyObject() throws {
        let config = Realm.Configuration(inMemoryIdentifier: UUID().uuidString)
        Realm.Configuration.defaultConfiguration = config

        let savedFolder = CPYFolder()
        savedFolder.index = 100
        savedFolder.title = "saved realm folder"

        let savedSnippet = CPYSnippet()
        savedSnippet.index = 10
        savedSnippet.title = "saved realm snippet"
        savedSnippet.content = "content"
        savedFolder.snippets.append(savedSnippet)

        let realm = try Realm()
        realm.transaction { realm.add(savedFolder) }

        #expect(savedFolder.realm != nil)
        #expect(savedSnippet.realm != nil)

        let folder = savedFolder.deepCopy()
        #expect(folder.realm == nil)
        #expect(folder.index == savedFolder.index)
        #expect(folder.enable == savedFolder.enable)
        #expect(folder.title == savedFolder.title)
        #expect(folder.identifier == savedFolder.identifier)
        #expect(folder.snippets.count == 1)

        let snippet = folder.snippets.first!
        #expect(snippet.realm == nil)
        #expect(snippet.index == savedSnippet.index)
        #expect(snippet.enable == savedSnippet.enable)
        #expect(snippet.title == savedSnippet.title)
        #expect(snippet.content == savedSnippet.content)
        #expect(snippet.identifier == savedSnippet.identifier)

        realm.transaction { realm.deleteAll() }
    }

    @Test func createFolder() throws {
        let config = Realm.Configuration(inMemoryIdentifier: UUID().uuidString)
        Realm.Configuration.defaultConfiguration = config

        let folder = CPYFolder.create()
        #expect(folder.title == "untitled folder")
        #expect(folder.index == 0)

        let realm = try Realm()
        realm.transaction { realm.add(folder) }

        let folder2 = CPYFolder.create()
        #expect(folder2.index == 1)

        realm.transaction { realm.deleteAll() }
    }

    @Test func createSnippet() {
        let folder = CPYFolder()
        let snippet = folder.createSnippet()

        #expect(snippet.title == "untitled snippet")
        #expect(snippet.index == 0)

        folder.snippets.append(snippet)

        let snippet2 = folder.createSnippet()
        #expect(snippet2.index == 1)
    }

    @Test func mergeSnippet() throws {
        let config = Realm.Configuration(inMemoryIdentifier: UUID().uuidString)
        Realm.Configuration.defaultConfiguration = config

        let folder = CPYFolder()
        let realm = try Realm()
        realm.transaction { realm.add(folder) }
        let copyFolder = folder.deepCopy()

        let snippet = CPYSnippet()
        let snippet2 = CPYSnippet()
        copyFolder.mergeSnippet(snippet)
        copyFolder.mergeSnippet(snippet2)

        #expect(snippet.realm == nil)
        #expect(snippet2.realm == nil)
        #expect(folder.snippets.count == 2)

        let savedSnippet = folder.snippets.first!
        let savedSnippet2 = folder.snippets[1]
        #expect(savedSnippet.identifier == snippet.identifier)
        #expect(savedSnippet2.identifier == snippet2.identifier)

        realm.transaction { realm.deleteAll() }
    }

    @Test func insertSnippet() throws {
        let config = Realm.Configuration(inMemoryIdentifier: UUID().uuidString)
        Realm.Configuration.defaultConfiguration = config

        let folder = CPYFolder()
        let realm = try Realm()
        realm.transaction { realm.add(folder) }
        let copyFolder = folder.deepCopy()

        let snippet = CPYSnippet()
        copyFolder.insertSnippet(snippet, index: 0)
        #expect(folder.snippets.count == 0)

        realm.transaction { realm.add(snippet) }

        copyFolder.insertSnippet(snippet, index: 0)
        #expect(folder.snippets.count == 1)

        realm.transaction { realm.deleteAll() }
    }

    @Test func removeSnippet() throws {
        let config = Realm.Configuration(inMemoryIdentifier: UUID().uuidString)
        Realm.Configuration.defaultConfiguration = config

        let folder = CPYFolder()
        let snippet = CPYSnippet()
        folder.snippets.append(snippet)
        let realm = try Realm()
        realm.transaction { realm.add(folder) }

        #expect(folder.snippets.count == 1)

        let copyFolder = folder.deepCopy()
        copyFolder.removeSnippet(snippet)

        #expect(folder.snippets.count == 0)

        realm.transaction { realm.deleteAll() }
    }

    @Test func mergeFolder() throws {
        let config = Realm.Configuration(inMemoryIdentifier: UUID().uuidString)
        Realm.Configuration.defaultConfiguration = config

        let realm = try Realm()
        #expect(realm.objects(CPYFolder.self).count == 0)

        let folder = CPYFolder()
        folder.index = 100
        folder.title = "title"
        folder.enable = false
        folder.merge()
        #expect(folder.realm == nil)
        #expect(realm.objects(CPYFolder.self).count == 1)

        let savedFolder = realm.object(ofType: CPYFolder.self, forPrimaryKey: folder.identifier)
        #expect(savedFolder != nil)
        #expect(savedFolder?.index == folder.index)
        #expect(savedFolder?.title == folder.title)
        #expect(savedFolder?.enable == folder.enable)

        folder.index = 1
        folder.title = "change title"
        folder.enable = true
        folder.merge()
        #expect(realm.objects(CPYFolder.self).count == 1)

        #expect(savedFolder?.index == folder.index)
        #expect(savedFolder?.title == folder.title)
        #expect(savedFolder?.enable == folder.enable)

        realm.transaction { realm.deleteAll() }
    }

    @Test func removeFolder() throws {
        let config = Realm.Configuration(inMemoryIdentifier: UUID().uuidString)
        Realm.Configuration.defaultConfiguration = config

        let folder = CPYFolder()
        let snippet = CPYSnippet()
        folder.snippets.append(snippet)
        let realm = try Realm()
        realm.transaction { realm.add(folder) }

        #expect(realm.objects(CPYFolder.self).count == 1)
        #expect(realm.objects(CPYSnippet.self).count == 1)

        let copyFolder = folder.deepCopy()
        #expect(copyFolder.realm == nil)
        copyFolder.remove()

        #expect(realm.objects(CPYFolder.self).count == 0)
        #expect(realm.objects(CPYSnippet.self).count == 0)

        realm.transaction { realm.deleteAll() }
    }

    @Test func rearrangeFolderIndex() throws {
        let config = Realm.Configuration(inMemoryIdentifier: UUID().uuidString)
        Realm.Configuration.defaultConfiguration = config

        let folder = CPYFolder()
        folder.index = 100
        let folder2 = CPYFolder()
        folder2.index = 10

        let realm = try Realm()
        realm.transaction { realm.add([folder, folder2]) }

        let copyFolder = folder.deepCopy()
        let copyFolder2 = folder2.deepCopy()

        CPYFolder.rearrangesIndex([copyFolder, copyFolder2])

        #expect(copyFolder.index == 0)
        #expect(copyFolder2.index == 1)
        #expect(folder.index == 0)
        #expect(folder2.index == 1)

        realm.transaction { realm.deleteAll() }
    }

    @Test func rearrangeSnippetIndex() throws {
        let config = Realm.Configuration(inMemoryIdentifier: UUID().uuidString)
        Realm.Configuration.defaultConfiguration = config

        let folder = CPYFolder()
        let snippet = CPYSnippet()
        snippet.index = 10
        let snippet2 = CPYSnippet()
        snippet2.index = 100
        folder.snippets.append(snippet)
        folder.snippets.append(snippet2)
        let realm = try Realm()
        realm.transaction { realm.add(folder) }

        let copyFolder = folder.deepCopy()
        copyFolder.rearrangesSnippetIndex()

        let copySnippet = copyFolder.snippets.first!
        let copySnippet2 = copyFolder.snippets[1]
        #expect(copySnippet.index == 0)
        #expect(copySnippet2.index == 1)
        #expect(snippet.index == 0)
        #expect(snippet2.index == 1)

        realm.transaction { realm.deleteAll() }
    }
}
```

- [ ] **Step 2: Create SnippetTests.swift**

Create `ClipyTests/SnippetTests.swift`:

```swift
import Testing
import RealmSwift
@testable import Clipy

struct SnippetTests {

    @Test func mergeSnippet() throws {
        let config = Realm.Configuration(inMemoryIdentifier: UUID().uuidString)
        Realm.Configuration.defaultConfiguration = config

        let snippet = CPYSnippet()
        let realm = try Realm()
        realm.transaction { realm.add(snippet) }

        let snippet2 = CPYSnippet()
        snippet2.identifier = snippet.identifier
        snippet2.index = 100
        snippet2.title = "title"
        snippet2.content = "content"
        snippet2.merge()
        #expect(snippet2.realm == nil)

        #expect(snippet.index == snippet2.index)
        #expect(snippet.title == snippet2.title)
        #expect(snippet.content == snippet2.content)

        realm.transaction { realm.deleteAll() }
    }

    @Test func removeSnippet() throws {
        let config = Realm.Configuration(inMemoryIdentifier: UUID().uuidString)
        Realm.Configuration.defaultConfiguration = config

        let realm = try Realm()
        #expect(realm.objects(CPYSnippet.self).count == 0)

        let snippet = CPYSnippet()
        realm.transaction { realm.add(snippet) }

        #expect(realm.objects(CPYSnippet.self).count == 1)

        let snippet2 = CPYSnippet()
        snippet2.identifier = snippet.identifier
        snippet2.remove()

        #expect(realm.objects(CPYSnippet.self).count == 0)

        realm.transaction { realm.deleteAll() }
    }
}
```

- [ ] **Step 3: Create DraggedDataTests.swift**

Create `ClipyTests/DraggedDataTests.swift`:

```swift
import Testing
import Foundation
@testable import Clipy

struct DraggedDataTests {

    @Test func archiveAndUnarchiveData() throws {
        let draggedData = CPYDraggedData(
            type: .folder,
            folderIdentifier: UUID().uuidString,
            snippetIdentifier: nil,
            index: 10
        )
        let data = try NSKeyedArchiver.archivedData(
            withRootObject: draggedData,
            requiringSecureCoding: false
        )

        let unarchiveData = try NSKeyedUnarchiver.unarchivedObject(
            ofClass: CPYDraggedData.self,
            from: data
        )
        #expect(unarchiveData != nil)
        #expect(unarchiveData?.type == draggedData.type)
        #expect(unarchiveData?.folderIdentifier == draggedData.folderIdentifier)
        #expect(unarchiveData?.snippetIdentifier == nil)
        #expect(unarchiveData?.index == draggedData.index)
    }
}
```

- [ ] **Step 4: Create HotKeyServiceTests.swift**

Create `ClipyTests/HotKeyServiceTests.swift`:

```swift
import Testing
import Magnet
import Carbon
@testable import Clipy

struct HotKeyServiceTests {

    private func cleanupDefaults() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: Constants.UserDefaults.hotKeys)
        defaults.removeObject(forKey: Constants.HotKey.migrateNewKeyCombo)
        defaults.removeObject(forKey: Constants.HotKey.mainKeyCombo)
        defaults.removeObject(forKey: Constants.HotKey.historyKeyCombo)
        defaults.removeObject(forKey: Constants.HotKey.snippetKeyCombo)
        defaults.removeObject(forKey: Constants.HotKey.clearHistoryKeyCombo)
        defaults.removeObject(forKey: Constants.HotKey.folderKeyCombos)
        defaults.synchronize()
    }

    @Test func migrateDefaultSettings() {
        cleanupDefaults()
        defer { cleanupDefaults() }

        let service = HotKeyService()
        #expect(service.mainKeyCombo == nil)
        #expect(service.historyKeyCombo == nil)
        #expect(service.snippetKeyCombo == nil)

        let defaults = UserDefaults.standard
        #expect(defaults.bool(forKey: Constants.HotKey.migrateNewKeyCombo) == false)
        service.setupDefaultHotKeys()
        #expect(defaults.bool(forKey: Constants.HotKey.migrateNewKeyCombo) == true)

        #expect(service.mainKeyCombo != nil)
        #expect(service.mainKeyCombo?.QWERTYKeyCode == 9)
        #expect(service.mainKeyCombo?.modifiers == 768)
        #expect(service.mainKeyCombo?.doubledModifiers == false)
        #expect(service.mainKeyCombo?.keyEquivalent.uppercased() == "V")

        #expect(service.historyKeyCombo != nil)
        #expect(service.historyKeyCombo?.QWERTYKeyCode == 9)
        #expect(service.historyKeyCombo?.modifiers == 4352)
        #expect(service.historyKeyCombo?.doubledModifiers == false)
        #expect(service.historyKeyCombo?.keyEquivalent.uppercased() == "V")

        #expect(service.snippetKeyCombo != nil)
        #expect(service.snippetKeyCombo?.QWERTYKeyCode == 11)
        #expect(service.snippetKeyCombo?.modifiers == 768)
        #expect(service.snippetKeyCombo?.doubledModifiers == false)
        #expect(service.snippetKeyCombo?.keyEquivalent.uppercased() == "B")
    }

    @Test func migrateCustomizeSettings() {
        cleanupDefaults()
        defer { cleanupDefaults() }

        let service = HotKeyService()
        let defaults = UserDefaults.standard
        let defaultKeyCombos: [String: Any] = [
            Constants.Menu.clip: ["keyCode": 0, "modifiers": 4352],
            Constants.Menu.history: ["keyCode": 9, "modifiers": 768],
            Constants.Menu.snippet: ["keyCode": 11, "modifiers": 4352]
        ]
        defaults.register(defaults: [Constants.UserDefaults.hotKeys: defaultKeyCombos])
        defaults.synchronize()

        #expect(defaults.bool(forKey: Constants.HotKey.migrateNewKeyCombo) == false)
        service.setupDefaultHotKeys()
        #expect(defaults.bool(forKey: Constants.HotKey.migrateNewKeyCombo) == true)

        #expect(service.mainKeyCombo != nil)
        #expect(service.mainKeyCombo?.QWERTYKeyCode == 0)
        #expect(service.mainKeyCombo?.modifiers == 4352)
        #expect(service.mainKeyCombo?.doubledModifiers == false)
        #expect(service.mainKeyCombo?.keyEquivalent.uppercased() == "A")

        #expect(service.historyKeyCombo != nil)
        #expect(service.historyKeyCombo?.QWERTYKeyCode == 9)
        #expect(service.historyKeyCombo?.modifiers == 768)
        #expect(service.historyKeyCombo?.doubledModifiers == false)
        #expect(service.historyKeyCombo?.keyEquivalent.uppercased() == "V")

        #expect(service.snippetKeyCombo != nil)
        #expect(service.snippetKeyCombo?.QWERTYKeyCode == 11)
        #expect(service.snippetKeyCombo?.modifiers == 4352)
        #expect(service.snippetKeyCombo?.doubledModifiers == false)
        #expect(service.snippetKeyCombo?.keyEquivalent.uppercased() == "B")
    }

    @Test func saveKeyCombos() {
        cleanupDefaults()
        defer { cleanupDefaults() }

        let defaults = UserDefaults.standard
        defaults.set(true, forKey: Constants.HotKey.migrateNewKeyCombo)
        defaults.synchronize()

        let service = HotKeyService()
        #expect(service.mainKeyCombo == nil)
        #expect(service.historyKeyCombo == nil)
        #expect(service.snippetKeyCombo == nil)

        #expect(defaults.archiveDataForKey(KeyCombo.self, key: Constants.HotKey.mainKeyCombo) == nil)
        #expect(defaults.archiveDataForKey(KeyCombo.self, key: Constants.HotKey.historyKeyCombo) == nil)
        #expect(defaults.archiveDataForKey(KeyCombo.self, key: Constants.HotKey.snippetKeyCombo) == nil)

        service.setupDefaultHotKeys()
        #expect(service.mainKeyCombo == nil)
        #expect(service.historyKeyCombo == nil)
        #expect(service.snippetKeyCombo == nil)

        let mainKeyCombo = KeyCombo(QWERTYKeyCode: 9, carbonModifiers: 768)
        let historyKeyCombo = KeyCombo(doubledCocoaModifiers: .command)
        let snippetKeyCombo = KeyCombo(QWERTYKeyCode: 0, cocoaModifiers: .shift)

        service.change(with: .main, keyCombo: mainKeyCombo)
        service.change(with: .history, keyCombo: historyKeyCombo)
        service.change(with: .snippet, keyCombo: snippetKeyCombo)

        let savedMain = defaults.archiveDataForKey(KeyCombo.self, key: Constants.HotKey.mainKeyCombo)
        let savedHistory = defaults.archiveDataForKey(KeyCombo.self, key: Constants.HotKey.historyKeyCombo)
        let savedSnippet = defaults.archiveDataForKey(KeyCombo.self, key: Constants.HotKey.snippetKeyCombo)

        #expect(savedMain != nil)
        #expect(savedMain?.QWERTYKeyCode == 9)
        #expect(savedMain?.modifiers == 768)
        #expect(savedMain?.doubledModifiers == false)
        #expect(savedMain?.keyEquivalent.uppercased() == "V")

        #expect(savedHistory != nil)
        #expect(savedHistory?.QWERTYKeyCode == 0)
        #expect(savedHistory?.modifiers == cmdKey)
        #expect(savedHistory?.doubledModifiers == true)
        #expect(savedHistory?.keyEquivalent.uppercased() == "")

        #expect(savedSnippet != nil)
        #expect(savedSnippet?.QWERTYKeyCode == 0)
        #expect(savedSnippet?.modifiers == shiftKey)
        #expect(savedSnippet?.doubledModifiers == false)
        #expect(savedSnippet?.keyEquivalent.uppercased() == "A")

        service.change(with: .main, keyCombo: nil)
        #expect(service.mainKeyCombo == nil)
        #expect(defaults.archiveDataForKey(KeyCombo.self, key: Constants.HotKey.mainKeyCombo) == nil)
    }

    @Test func unarchiveSavedKeyCombos() {
        cleanupDefaults()
        defer { cleanupDefaults() }

        let mainKeyCombo = KeyCombo(QWERTYKeyCode: 9, carbonModifiers: 768)
        let historyKeyCombo = KeyCombo(doubledCocoaModifiers: .command)
        let snippetKeyCombo = KeyCombo(QWERTYKeyCode: 0, cocoaModifiers: .shift)

        let defaults = UserDefaults.standard
        defaults.set(true, forKey: Constants.HotKey.migrateNewKeyCombo)
        defaults.setArchiveData(mainKeyCombo!, forKey: Constants.HotKey.mainKeyCombo)
        defaults.setArchiveData(historyKeyCombo!, forKey: Constants.HotKey.historyKeyCombo)
        defaults.setArchiveData(snippetKeyCombo!, forKey: Constants.HotKey.snippetKeyCombo)

        let service = HotKeyService()
        service.setupDefaultHotKeys()

        #expect(service.mainKeyCombo != nil)
        #expect(service.mainKeyCombo?.QWERTYKeyCode == 9)
        #expect(service.mainKeyCombo?.modifiers == 768)

        #expect(service.historyKeyCombo != nil)
        #expect(service.historyKeyCombo?.QWERTYKeyCode == 0)
        #expect(service.historyKeyCombo?.modifiers == cmdKey)
        #expect(service.historyKeyCombo?.doubledModifiers == true)

        #expect(service.snippetKeyCombo != nil)
        #expect(service.snippetKeyCombo?.QWERTYKeyCode == 0)
        #expect(service.snippetKeyCombo?.modifiers == shiftKey)
        #expect(service.snippetKeyCombo?.doubledModifiers == false)
    }

    @Test func defaultKeyCombos() {
        let keyCombos = HotKeyService.defaultKeyCombos
        let mainCombos = keyCombos[Constants.Menu.clip] as? [String: Int]
        let historyCombos = keyCombos[Constants.Menu.history] as? [String: Int]
        let snippetCombos = keyCombos[Constants.Menu.snippet] as? [String: Int]

        #expect(mainCombos?["keyCode"] == 9)
        #expect(mainCombos?["modifiers"] == 768)
        #expect(historyCombos?["keyCode"] == 9)
        #expect(historyCombos?["modifiers"] == 4352)
        #expect(snippetCombos?["keyCode"] == 11)
        #expect(snippetCombos?["modifiers"] == 768)
    }

    @Test func clearHistoryHotKey() {
        cleanupDefaults()
        defer { cleanupDefaults() }

        let service = HotKeyService()
        #expect(service.clearHistoryKeyCombo == nil)

        let keyCombo = KeyCombo(QWERTYKeyCode: 10, carbonModifiers: cmdKey)
        service.changeClearHistoryKeyCombo(keyCombo)

        #expect(service.clearHistoryKeyCombo != nil)
        #expect(service.clearHistoryKeyCombo == keyCombo)

        let savedData = UserDefaults.standard.object(forKey: Constants.HotKey.clearHistoryKeyCombo) as? Data
        let savedKeyCombo = NSKeyedUnarchiver.unarchiveObject(with: savedData!) as? KeyCombo
        #expect(savedKeyCombo == keyCombo)

        service.changeClearHistoryKeyCombo(nil)
        #expect(service.clearHistoryKeyCombo == nil)
    }

    @Test func folderHotKey() {
        cleanupDefaults()
        defer { cleanupDefaults() }

        let service = HotKeyService()
        let identifier = UUID().uuidString
        #expect(service.snippetKeyCombo(forIdentifier: identifier) == nil)

        let keyCombo = KeyCombo(QWERTYKeyCode: 0, carbonModifiers: cmdKey)!
        service.registerSnippetHotKey(with: identifier, keyCombo: keyCombo)

        #expect(service.snippetKeyCombo(forIdentifier: identifier) != nil)
        #expect(service.snippetKeyCombo(forIdentifier: identifier) == keyCombo)

        let changeKeyCombo = KeyCombo(doubledCarbonModifiers: shiftKey)!
        service.registerSnippetHotKey(with: identifier, keyCombo: changeKeyCombo)

        #expect(service.snippetKeyCombo(forIdentifier: identifier) != keyCombo)
        #expect(service.snippetKeyCombo(forIdentifier: identifier) == changeKeyCombo)

        service.unregisterSnippetHotKey(with: identifier)
        #expect(service.snippetKeyCombo(forIdentifier: identifier) == nil)
    }
}
```

- [ ] **Step 5: Delete old spec files and add new test files to Xcode project**

Delete the old files and add the new ones to the Xcode project. In Xcode, remove `FolderSpec.swift`, `SnippetSpec.swift`, `DraggedDataSpec.swift`, `HotKeyServiceSpec.swift` from the ClipyTests target, then add the four new `*Tests.swift` files.

```bash
rm ClipyTests/FolderSpec.swift ClipyTests/SnippetSpec.swift ClipyTests/DraggedDataSpec.swift ClipyTests/HotKeyServiceSpec.swift
```

- [ ] **Step 6: Commit**

```bash
git add ClipyTests/ Clipy.xcodeproj/project.pbxproj
git commit -m "Migrate tests from Quick/Nimble to Swift Testing"
```

---

### Task 7: Update deployment target and build settings

Change the deployment target from macOS 10.10 to macOS 14.0 in the Xcode project.

**Files:**
- Modify: `Clipy.xcodeproj/project.pbxproj` (via Xcode)

- [ ] **Step 1: Update deployment target**

Open `Clipy.xcodeproj` in Xcode. For both the `Clipy` target and `ClipyTests` target, and also the project-level build settings:
- Set **macOS Deployment Target** to `14.0`

This must be done in Xcode's Build Settings UI to update all configurations (Debug and Release) correctly.

- [ ] **Step 2: Update Swift Language Version**

In Xcode Build Settings for both targets:
- Set **Swift Language Version** to `Swift 5` (or `5.10` if available in picker)

- [ ] **Step 3: Commit**

```bash
git add Clipy.xcodeproj/project.pbxproj
git commit -m "Raise deployment target to macOS 14.0, Swift 5.10"
```

---

### Task 8: Migrate from CocoaPods to Swift Package Manager

This is the core migration. Remove CocoaPods integration and add all dependencies as Swift packages. This task must be done in Xcode.

**Files:**
- Delete: `Podfile`
- Delete: `Podfile.lock`
- Delete: `Clipy.xcworkspace/`
- Modify: `Clipy.xcodeproj/project.pbxproj` (via Xcode — remove pod build phases, add SPM packages)

- [ ] **Step 1: Record current pod versions for reference**

These are the target SPM versions to add:

| Package | SPM URL | Version |
|---------|---------|---------|
| RealmSwift | `https://github.com/realm/realm-swift.git` | 20.x (latest) |
| RxSwift (includes RxCocoa, RxRelay) | `https://github.com/ReactiveX/RxSwift.git` | 6.x (latest) |
| RxScreeen | `https://github.com/Clipy/RxScreeen.git` | 2.2.0 |
| Sparkle | `https://github.com/sparkle-project/Sparkle.git` | 2.9.x (latest 2.x) |
| Sauce | `https://github.com/Clipy/Sauce.git` | 2.5.0 |
| KeyHolder | `https://github.com/Clipy/KeyHolder.git` | 4.2.0 |
| Magnet | `https://github.com/Clipy/Magnet.git` | 3.5.0 |
| PINCache | `https://github.com/pinterest/PINCache.git` | 3.0.4 |
| AEXML | `https://github.com/tadija/AEXML.git` | 4.7.0 |

Packages NOT migrated (removed): LoginServiceKit, LetsMove, SwiftHEXColors, Quick, Nimble, SwiftLint, SwiftGen, BartyCrouch.

- [ ] **Step 2: Remove CocoaPods integration from Xcode project**

In the Xcode project, delete these build phases (visible in Build Phases tab):
- `[CP] Check Pods Manifest.lock` (appears twice — one for Clipy target, one for ClipyTests)
- `[CP] Embed Pods Frameworks` (appears twice)
- `Pods-Clipy` and `Pods-ClipyTests` framework references

You can run `pod deintegrate` first if CocoaPods is installed:
```bash
bundle exec pod deintegrate
```

- [ ] **Step 3: Add Swift packages in Xcode**

Open `Clipy.xcodeproj` (NOT the workspace) in Xcode. Go to File → Add Package Dependencies. Add each package from the table in Step 1 with the specified version.

For each package, ensure the library is added to the correct target:
- All app libraries → `Clipy` target
- No test-only libraries needed (Swift Testing is built-in)

- [ ] **Step 4: Delete CocoaPods files**

```bash
rm Podfile Podfile.lock
rm -rf Clipy.xcworkspace
```

- [ ] **Step 5: Build to verify**

Run: `xcodebuild build -project Clipy.xcodeproj -scheme Clipy -destination 'platform=macOS' | tail -5`
Expected: `** BUILD SUCCEEDED **`

Note: The build command now uses `-project` instead of `-workspace`.

- [ ] **Step 6: Run tests**

Run: `xcodebuild test -project Clipy.xcodeproj -scheme Clipy -destination 'platform=macOS' | tail -10`
Expected: All tests pass.

- [ ] **Step 7: Commit**

```bash
git add Clipy.xcodeproj/
git rm Podfile Podfile.lock
git rm -r Clipy.xcworkspace/
git commit -m "Migrate from CocoaPods to Swift Package Manager"
```

---

### Task 9: Update Realm migration for 20.x

Realm 20.x has API changes in the migration block. The `Realm.Configuration` init and migration closure signatures may differ. Update accordingly.

**Files:**
- Modify: `Clipy/Sources/Extensions/Realm+Migration.swift`

- [ ] **Step 1: Update migration code**

Review `Clipy/Sources/Extensions/Realm+Migration.swift` after the Realm 20.x package resolves. The current migration block (schema version 7) should continue to work, but verify that:

1. `Realm.Configuration(schemaVersion:migrationBlock:)` still accepts the same signature
2. `migration.enumerateObjects(ofType:)` API hasn't changed
3. Schema version stays at 7 (no new model changes in this phase)

If Realm 20.x changed the `Migration` API, update the closure signatures accordingly. The migration logic itself (the field copies) stays the same.

- [ ] **Step 2: Build and test**

Run: `xcodebuild test -project Clipy.xcodeproj -scheme Clipy -destination 'platform=macOS' | tail -10`
Expected: All tests pass (Folder and Snippet tests exercise Realm).

- [ ] **Step 3: Commit (if changes needed)**

```bash
git add Clipy/Sources/Extensions/Realm+Migration.swift
git commit -m "Update Realm migration for 20.x API compatibility"
```

---

### Task 10: Move build tools to Homebrew and update build phases

SwiftLint, SwiftGen, and BartyCrouch are currently pods referenced in Xcode build phases by their `${PODS_ROOT}/` paths. Switch to Homebrew-installed binaries.

**Files:**
- Modify: `Clipy.xcodeproj/project.pbxproj` (build phase scripts, via Xcode)
- Modify: `.swiftlint.yml` (if rule updates needed for 0.63+)

- [ ] **Step 1: Install tools via Homebrew**

```bash
brew install swiftlint swiftgen bartycrouch
```

- [ ] **Step 2: Update Xcode build phases**

In Xcode, go to the Clipy target → Build Phases. Update the three shell script phases:

**SwiftLint** — change:
```bash
# OLD:
"${PODS_ROOT}/SwiftLint/swiftlint"

# NEW:
if command -v swiftlint >/dev/null 2>&1; then
    swiftlint
fi
```

**SwiftGen** — change:
```bash
# OLD:
"${PODS_ROOT}/SwiftGen/bin/swiftgen"

# NEW:
if command -v swiftgen >/dev/null 2>&1; then
    swiftgen
fi
```

**BartyCrouch** — change:
```bash
# OLD:
"${PODS_ROOT}/BartyCrouch/bartycrouch" interfaces -p "$PROJECT_DIR"

# NEW:
if command -v bartycrouch >/dev/null 2>&1; then
    bartycrouch interfaces -p "$PROJECT_DIR"
fi
```

The `if command -v` guards prevent build failures if the tool isn't installed (e.g., on CI or a new dev machine).

- [ ] **Step 3: Update SwiftLint config if needed**

Run `swiftlint` and check for deprecated/renamed rules. SwiftLint 0.63 may have renamed rules from the 0.40 config. Fix any warnings about unknown rules in `.swiftlint.yml`.

```bash
swiftlint --config .swiftlint.yml 2>&1 | head -20
```

- [ ] **Step 4: Commit**

```bash
git add Clipy.xcodeproj/project.pbxproj .swiftlint.yml
git commit -m "Move SwiftLint, SwiftGen, BartyCrouch to Homebrew"
```

---

### Task 11: Update CI workflows and remove Ruby

Replace the Ruby/Fastlane-based CI with direct xcodebuild. Delete the Danger workflow. Remove all Ruby files.

**Files:**
- Modify: `.github/workflows/CI.yml`
- Delete: `.github/workflows/Danger.yml`
- Delete: `Gemfile`
- Delete: `Gemfile.lock`
- Delete: `Dangerfile`
- Delete: `fastlane/` directory

- [ ] **Step 1: Rewrite CI.yml**

Replace `.github/workflows/CI.yml` with:

```yaml
name: CI

on: [push, pull_request]

jobs:
  test:
    runs-on: macos-14
    steps:
    - uses: actions/checkout@v4

    - name: Select Xcode
      run: sudo xcode-select -s /Applications/Xcode_16.2.app/Contents/Developer

    - name: Resolve packages
      run: xcodebuild -resolvePackageDependencies -project Clipy.xcodeproj -scheme Clipy

    - name: Build and test
      run: xcodebuild test -project Clipy.xcodeproj -scheme Clipy -destination 'platform=macOS' -resultBundlePath TestResults

  lint:
    runs-on: macos-14
    steps:
    - uses: actions/checkout@v4

    - name: Install SwiftLint
      run: brew install swiftlint

    - name: Lint
      run: swiftlint --config .swiftlint.yml --strict
```

- [ ] **Step 2: Delete Danger workflow**

```bash
rm .github/workflows/Danger.yml
```

- [ ] **Step 3: Delete Ruby files and Fastlane**

```bash
rm Gemfile Gemfile.lock Dangerfile
rm -rf fastlane
```

- [ ] **Step 4: Update .gitignore**

Remove any CocoaPods/Ruby-related entries from `.gitignore` if present. Add SPM-related entries if missing:

```gitignore
# Swift Package Manager
.build/
.swiftpm/
```

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/CI.yml .gitignore
git rm .github/workflows/Danger.yml Gemfile Gemfile.lock Dangerfile
git rm -r fastlane
git commit -m "Replace Fastlane/Danger/Ruby CI with direct xcodebuild and SwiftLint action"
```

---

### Task 12: Update CLAUDE.md and README.md

Update project documentation to reflect the new build system.

**Files:**
- Modify: `CLAUDE.md`
- Modify: `README.md`

- [ ] **Step 1: Update CLAUDE.md**

Update the Build & Run section:
```markdown
## Build & Run

```bash
# Open project in Xcode
open Clipy.xcodeproj

# Build and test from command line
xcodebuild test -project Clipy.xcodeproj -scheme Clipy -destination 'platform=macOS'
```

Build and run from Xcode using the `Clipy` scheme. Dependencies are managed via Swift Package Manager — Xcode resolves them automatically on first open.
```

Update the Linting section:
```markdown
## Linting

SwiftLint installed via Homebrew:
```bash
brew install swiftlint
swiftlint
```
```

Remove references to CocoaPods, Ruby, Fastlane, Quick/Nimble.

- [ ] **Step 2: Update README.md**

Update the "How to Build" section:
```markdown
### How to Build
0. Move to the project root directory
1. Open `Clipy.xcodeproj` on Xcode.
2. Build.

Dependencies are managed via Swift Package Manager and resolve automatically.
```

Update the "Development Environment" section:
```markdown
### Development Environment
* macOS 14 Sonoma or higher
* Xcode 16+
* Swift 5.10+
```

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md README.md
git commit -m "Update docs for SPM build system and macOS 14 target"
```

---

### Task 13: Final verification

End-to-end build and test to confirm everything works.

- [ ] **Step 1: Clean build**

```bash
xcodebuild clean build -project Clipy.xcodeproj -scheme Clipy -destination 'platform=macOS' | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 2: Run all tests**

```bash
xcodebuild test -project Clipy.xcodeproj -scheme Clipy -destination 'platform=macOS' | tail -10
```
Expected: All tests pass.

- [ ] **Step 3: Run SwiftLint**

```bash
swiftlint --config .swiftlint.yml
```
Expected: No errors (warnings acceptable for now).

- [ ] **Step 4: Verify no stale references**

```bash
grep -r "PODS_ROOT\|pod install\|bundle exec\|Podfile\|CocoaPods" Clipy.xcodeproj/project.pbxproj
grep -r "import Quick\|import Nimble\|import LoginServiceKit\|import LetsMove\|import SwiftHEXColors" Clipy/Sources/ ClipyTests/
```
Expected: No matches.

- [ ] **Step 5: Verify files deleted**

```bash
ls Podfile Podfile.lock Gemfile Gemfile.lock Dangerfile 2>&1
ls -d Clipy.xcworkspace fastlane 2>&1
```
Expected: All return "No such file or directory".
