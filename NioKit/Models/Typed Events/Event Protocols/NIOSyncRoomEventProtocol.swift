import SwiftMatrixSDK

/// Sync Room Event \
/// ([API Schema](https://github.com/matrix-org/matrix-doc/blob/master/event-schemas/schema/core-event-schema/sync_room_event.yaml))
///
/// The basic set of fields all sync room events must have.
public protocol NIOSyncRoomEventProtocol: NIOEventProtocol {
    /// The globally unique event identifier.
    var eventId: String { get }

    /// Contains the fully-qualified ID of the user who sent this event.
    var sender: String { get }

    /// Timestamp in milliseconds on originating homeserver when this event was sent.
    var originServerTs: UInt64 { get }

    /// Contains optional extra information about the event.
    var unsignedData: MXEventUnsignedData? { get }
}

extension NIOSyncRoomEventProtocol where Self: MXEventProvider {
    public var eventId: String {
        self.event.eventId
    }

    public var sender: String {
        self.event.sender
    }

    public var originServerTs: UInt64 {
        self.event.originServerTs
    }

    public var unsignedData: MXEventUnsignedData? {
        self.event.unsignedData
    }
}

extension MXEventValidator {
    internal static func validate(event: MXEvent, for: NIOSyncRoomEventProtocol.Protocol) throws {
        struct Key {
            static let eventId: String = "event_id"
            static let sender: String = "sender"
            static let originServerTs: String = "origin_server_ts"
            static let unsignedData: String = "unsigned"
        }

        try self.validate(event: event, for: NIOEventProtocol.self)

        try self.expect(value: event.eventId, is: String.self)
        try self.expect(value: event.sender, is: String.self)

        // NOTE: originServerTs is non-optional

        try self.expect(value: event.unsignedData, is: MXEventUnsignedData?.self)

        if let _ = event.unsignedData {
            // FIXME: perform deep validation?
        }
    }
}

internal func == (lhs: NIOSyncRoomEventProtocol, rhs: NIOSyncRoomEventProtocol) -> Bool {
    guard (lhs as NIOEventProtocol) == (rhs as NIOEventProtocol) else {
        return false
    }
    guard lhs.eventId == rhs.eventId else {
        return false
    }
    guard lhs.sender == rhs.sender else {
        return false
    }
    guard lhs.originServerTs == rhs.originServerTs else {
        return false
    }
    guard lhs.unsignedData == rhs.unsignedData else {
        return false
    }
    return true
}
