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

    var lastMessageDate: Date {
        let ts = Double(summary.lastMessageOriginServerTs)
        return Date(timeIntervalSince1970: ts / 1000)
    }
}
