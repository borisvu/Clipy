# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Clipy is a clipboard history manager for macOS, written in Swift. It runs as a status bar app, monitors the system pasteboard, stores clipboard entries in Realm, and lets users recall them via configurable hotkeys or menu interaction. It also supports user-defined text snippets organized into folders.

## Build & Run

```bash
# Open project in Xcode
open Clipy.xcodeproj

# Build and test from command line
xcodebuild test -project Clipy.xcodeproj -scheme Clipy -destination 'platform=macOS'
```

Build and run from Xcode using the `Clipy` scheme in `Clipy.xcodeproj`. Dependencies are managed via Swift Package Manager — Xcode resolves them automatically on first open.

## Linting

SwiftLint installed via Homebrew:
```bash
brew install swiftlint
swiftlint
```
Config is in `.swiftlint.yml`. Only `Clipy/Sources` and `ClipyTests` are linted. Notable: `line_length` is 300, `todo` rule is disabled, `force_try` is disabled.

## Code Generation

SwiftGen generates type-safe accessors. Config is in `swiftgen.yml`. Generated files live in `Clipy/Generated/` — don't edit them directly:
- `LocalizedStrings.swift` — localized strings accessed via `L10n.*`
- `AssetsImages.swift` — image assets accessed via `Asset.*`
- `Colors.swift` — color definitions

## Architecture

### Environment / Dependency Injection

All services are held in an `Environment` struct and accessed through `AppEnvironment.current`. The environment is a stack — you can push/pop environments, which is how tests substitute services. Access any service via `AppEnvironment.current.<service>`.

Services:
- **ClipService** — polls `NSPasteboard.general` every 750μs via RxSwift timer, creates `CPYClipData` from new pasteboard content, persists to Realm
- **HotKeyService** — registers global hotkeys via the Magnet framework; default shortcuts are Cmd+Shift+V (main), Cmd+Ctrl+V (history), Cmd+Shift+B (snippets)
- **PasteService** — writes selected clip data back to the pasteboard and simulates Cmd+V
- **MenuManager** — builds and manages the three NSMenus (main clip menu, history, snippets) shown from the status bar; rebuilds menus reactively via Realm notifications
- **DataCleanService** — cleans up old clipboard data files
- **ExcludeAppService** — tracks apps whose clipboard content should be ignored

### Data Layer

Realm is the persistence layer. Schema version is 7 with migrations in `Realm+Migration.swift`.

Models:
- `CPYClip` (Realm Object) — metadata for a clipboard entry; primary key is `dataHash`
- `CPYClipData` (NSCoding) — the actual clipboard payload (string, RTF, PDF, images, filenames, URLs); serialized to `.data` files in Application Support
- `CPYFolder` / `CPYSnippet` (Realm Objects) — user-defined snippet folders and entries

Thumbnails/images are cached via PINCache, keyed by unix timestamp.

### Reactive Patterns

The app uses RxSwift/RxCocoa extensively for binding UserDefaults changes to UI/menu updates, observing pasteboard changes, and screenshot monitoring via RxScreeen.

## Testing

Tests use Swift Testing and live in `ClipyTests/`. Run with Xcode's test runner (Cmd+U) or from command line:
```bash
xcodebuild test -project Clipy.xcodeproj -scheme Clipy -destination 'platform=macOS'
```
Test files exist for `CPYFolder`, `CPYSnippet`, `CPYDraggedData`, and `HotKeyService`.

## Localization

Supported: English (base), Japanese, German, Italian, Chinese (Simplified). Strings are in `Clipy/Resources/<lang>.lproj/Localizable.strings`. XIBs have per-language `.lproj` variants under `Preferences/Panels/` and `Snippets/`. BartyCrouch (installed via Pods) assists with localization management.

## Key Dependencies

Dependencies are managed via Swift Package Manager (SPM).

- **RealmSwift** — local database for clips, folders, snippets
- **RxSwift/RxCocoa** — reactive bindings throughout the app
- **Magnet/KeyHolder/Sauce** — global hotkey registration and UI
- **PINCache** — thumbnail image caching
- **Sparkle** — auto-update via appcast
- **AEXML** — snippet import/export via XML
