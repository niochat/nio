import Foundation
import MatrixSDK

@dynamicMemberLookup
public class NIORoomSummary: ObservableObject {
    internal var summary: MXRoomSummary

    public var lastMessageDate: Date {
        let timestamp = Double(summary.lastMessageOriginServerTs)
        return Date(timeIntervalSince1970: timestamp / 1000)
    }

    public init(_ summary: MXRoomSummary) {
        self.summary = summary
    }

    public subscript<T>(dynamicMember keyPath: KeyPath<MXRoomSummary, T>) -> T {
        summary[keyPath: keyPath]
    }
}
