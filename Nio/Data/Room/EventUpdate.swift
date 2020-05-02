import SwiftMatrixSDK

enum EventUpdate {
    case backwards(events: [MatrixEvent])
    case forwards(events: [MatrixEvent])
}
