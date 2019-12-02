import Foundation
import SwiftMatrixSDK

extension MXEvent {
    var timestamp: Date {
        Date(timeIntervalSince1970: TimeInterval(self.originServerTs / 1000))
    }
}
