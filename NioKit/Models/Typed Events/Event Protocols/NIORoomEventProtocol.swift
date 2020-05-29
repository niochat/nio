import SwiftMatrixSDK

/// Room Event \
/// ([API Schema](https://github.com/matrix-org/matrix-doc/blob/master/event-schemas/schema/core-event-schema/room_event.yaml))
///
/// The basic set of fields all room events must have.
public protocol NIORoomEventProtocol: NIOSyncRoomEventProtocol {
    /// The ID of the room associated with this event. Will not be present on events
    /// that arrive through `/sync`, despite being required everywhere else.
    var roomId: String { get }
}

extension NIORoomEventProtocol where Self: MXEventProvider {
    public var roomId: String {
        self.event.roomId
    }
}

extension MXEventValidator {
    internal static func validate(event: MXEvent, for: NIORoomEventProtocol.Protocol) throws {
        struct Key {
            static let roomId: String = "room_id"
        }

        try self.validate(event: event, for: NIOSyncRoomEventProtocol.self)

        try self.expect(value: event.roomId, is: String.self)
    }
}
