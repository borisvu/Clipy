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
