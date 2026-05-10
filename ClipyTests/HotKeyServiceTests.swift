import Testing
import Foundation
import Magnet
import Carbon
@testable import Clipy

@Suite(.serialized)
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
