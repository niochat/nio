import SwiftMatrixSDK

/// Sync State Event \
/// ([API Schema](https://github.com/matrix-org/matrix-doc/blob/master/event-schemas/schema/core-event-schema/sync_state_event.yaml))
///
/// The basic set of fields all sync state events must have.
public protocol NIOSyncStateEventProtocol: NIOSyncRoomEventProtocol {
    /// A unique key which defines the overwriting semantics for this piece
    /// of room state. This value is often a zero-length string. The presence of this
    /// key makes this event a State Event.
    ///
    /// State keys starting with an ``@`` are reserved for referencing user IDs, such
    /// as room members. With the exception of a few events, state events set with a
    /// given user's ID as the state key MUST only be set by that
    /// user.
    var stateKey: String { get }

    /// The previous ``content`` for this event.
    /// /// If there is no previous content, this key will be missing.
    var prevContent: [String: Any]? { get }
}

extension NIOSyncStateEventProtocol where Self: MXEventProvider {
    public var stateKey: String {
        self.event.sender
    }

    public var prevContent: [String: Any]? {
        self.event.prevContent
    }
}

extension MXEventValidator {
    internal static func validate(event: MXEvent, for: NIOSyncStateEventProtocol.Protocol) throws {
        struct Key {
            static let stateKey: String = "state_key"
            static let prevContent: String = "prev_content"
        }

        try self.validate(event: event, for: NIOSyncRoomEventProtocol.self)

        try self.expect(value: event.stateKey, equals: "")
        try self.expect(value: event.prevContent, is: [String: Any]?.self)

        if let _ = event.prevContent {
            // FIXME: perform deep validation?
        }
    }
}
