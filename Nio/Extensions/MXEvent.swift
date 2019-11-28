import Foundation
import SwiftMatrixSDK

extension MXEvent {
    var timestamp: Date {
        // FIXME: This is wrong, but how does this work?
        Date(timeIntervalSinceNow: -1 * Double(age))
    }
}
