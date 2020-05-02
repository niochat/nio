import SwiftMatrixSDK

enum EventUpdate {
    case backwards(events: [Event])
    case forwards(events: [Event])
}
