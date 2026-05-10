<div align="center">
  <img src="./Resources/clipy_logo.png" width="400">
</div>

<br>

Clipy is a Clipboard extension app for macOS.

This is a modernized fork of [Clipy](https://github.com/Clipy/Clipy), updated for Apple Silicon and current macOS.

---

__Requirement__: macOS 14 Sonoma or higher

### What Changed in This Fork

- Runs natively on Apple Silicon (M-series Macs)
- Deployment target raised to macOS 14
- Migrated from CocoaPods to Swift Package Manager
- Upgraded all dependencies (Realm 20.x, RxSwift 6.x, Sparkle 2.x)
- Replaced abandoned dependencies (LoginServiceKit, LetsMove, SwiftHEXColors)
- Migrated tests from Quick/Nimble to Swift Testing
- Eliminated Ruby toolchain (no more Gemfile, Fastlane, Danger)
- Fixed deprecated macOS APIs (pasteboard types, NSKeyedArchiver, NSStatusItem)
- Enabled Hardened Runtime
- Version 2.0.0

### Development Environment
* macOS 14 Sonoma or higher
* Xcode 16+
* Swift 5.10+

### How to Build
0. Move to the project root directory
1. Open `Clipy.xcodeproj` on Xcode.
2. Build.

Dependencies are managed via Swift Package Manager and resolve automatically.

### Contributing
1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

### Licence
This fork is available under the MIT license. See the LICENSE file for more info.

The original Clipy is Copyright (c) 2015-2018 Clipy Project, available under the MIT license.

Icons are copyrighted by their respective authors.

### Special Thanks
__Thank you to [@naotaka](https://github.com/naotaka) who published [ClipMenu](https://github.com/naotaka/ClipMenu) as OSS, and to the [Clipy Project](https://github.com/Clipy) for building on it.__
