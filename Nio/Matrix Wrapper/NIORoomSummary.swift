import Foundation
import SwiftMatrixSDK

@dynamicMemberLookup
class NIORoomSummary: ObservableObject {
    private var summary: MXRoomSummary

    init(_ summary: MXRoomSummary) {
        self.summary = summary
    }

    subscript<T>(dynamicMember keyPath: KeyPath<MXRoomSummary, T>) -> T {
        summary[keyPath: keyPath]
    }
}
