import Foundation
import SwiftMatrixSDK

extension MXRoomSummary {
    var lastMessageDate: Date {
        let ts = Double(lastMessageOriginServerTs)
        return Date(timeIntervalSince1970: ts / 1000)
    }
}
