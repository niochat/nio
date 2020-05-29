import SwiftMatrixSDK

public protocol NIORoomNameEventProtocol: NIORoomStateEventProtocol {
    /// The name of the room. This MUST NOT exceed 255 bytes.
    var roomName: String { get }
}

/// Room Name Event \
/// ([API Schema](https://github.com/matrix-org/matrix-doc/blob/master/event-schemas/schema/m.room.name))
///
/// A room has an opaque room ID which is not human-friendly to read. A room
/// alias is human-friendly, but not all rooms have room aliases. The room name
/// is a human-friendly string designed to be displayed to the end-user. The
/// room name is not unique, as multiple rooms can have the same room name set.
///
/// A room with an ``m.room.name`` event with an absent, null, or empty
/// ``name`` field should be treated the same as a room with no ``m.room.name``
/// event.
///
/// An event of this type is automatically created when creating a room using
/// ``/createRoom`` with the ``name`` key.
public struct NIORoomNameEvent: MXEventInitializable, MXEventProvider {
    fileprivate struct Key {
        static let type: String = "type"
        static let stateKey: String = "state_key"
        static let roomName: String = "name"
    }

    public let event: MXEvent

    public init(event: MXEvent) throws {
        try MXEventValidator.validate(event: event, for: Self.self)

        self.event = event
    }
}

extension NIORoomNameEvent: NIOSyncStateEventProtocol {}

extension NIORoomNameEvent {
    public var roomName: String {
        // swiftlint:disable:next force_cast
        return self.content[Key.roomName] as! String
    }
}

extension MXEventValidator {
    internal static func validate(event: MXEvent, for: NIORoomNameEvent.Type) throws {
        typealias Key = NIORoomNameEvent.Key

        try self.validate(event: event, for: NIOSyncStateEventProtocol.self)

        try self.expect(value: event.type, equals: "m.room.name")
        try self.expect(value: event.stateKey, equals: "")

        try self.expect(value: event.content[Key.roomName], is: String.self)
    }
}
