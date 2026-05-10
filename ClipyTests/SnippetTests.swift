import Testing
import Foundation
import RealmSwift
@testable import Clipy

@Suite(.serialized)
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
