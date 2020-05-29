import SwiftMatrixSDK

/// Room State Event \
/// ([API Schema](https://github.com/matrix-org/matrix-doc/blob/master/event-schemas/schema/core-event-schema/state_event.yaml))
///
/// The basic set of fields all room state events must have.
public protocol NIORoomStateEventProtocol: NIORoomEventProtocol, NIOSyncStateEventProtocol {}

extension MXEventValidator {
    internal static func validate(event: MXEvent, for: NIORoomStateEventProtocol.Protocol) throws {
        try self.validate(event: event, for: NIORoomEventProtocol.self)
        try self.validate(event: event, for: NIOSyncStateEventProtocol.self)
    }
}
