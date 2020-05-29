import SwiftMatrixSDK

public protocol NIORoomMessageEventProtocol: NIORoomStateEventProtocol {
    /// The textual representation of this message.
    var body: String { get }

    // FIXME: promote to an enum?
    /// The type of message, e.g. ``m.image``, ``m.text``
    var messageType: String { get }
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
public struct NIORoomMessageEvent: MXEventInitializable, MXEventProvider {
    fileprivate struct Key {
        static let body: String = "body"
        static let messageType: String = "msgtype"
        static let relatesTo: String = "m.relates_to"

        struct RelatesTo {
            static let inReplyTo: String = "m.in_reply_to"
        }
    }

    public let event: MXEvent

    public init(event: MXEvent) throws {
        try MXEventValidator.validate(event: event, for: Self.self)

        self.event = event
    }
}

extension NIORoomMessageEvent: NIORoomEventProtocol {}

extension NIORoomMessageEvent {
    public var body: String {
        // swiftlint:disable:next force_cast
        return self.content[Key.body] as! String
    }

    public var messageType: String {
        // swiftlint:disable:next force_cast
        return self.content[Key.messageType] as! String
    }

    public var relationships: AnyCollection<NIORoomMessageEventReplyRelationshipProtocol>? {
        guard let dictionary = self.event.content[Key.relatesTo] as? [String: Any] else {
            return nil
        }
        
        return AnyCollection(dictionary.compactMap { key, value in
            guard let json = value as? [String: Any] else {
                return nil
            }

            switch key {
            case Key.RelatesTo.inReplyTo:
                return try? NIORoomMessageEventReplyRelationship(fromJSON: json)
            case _:
                return nil
            }
        })
    }
}

extension MXEventValidator {
    internal static func validate(event: MXEvent, for: NIORoomMessageEvent.Type) throws {
        typealias Key = NIORoomMessageEvent.Key

        try self.validate(event: event, for: NIOSyncStateEventProtocol.self)

        try self.expect(value: event.type, equals: "m.room.message")

        try self.expect(value: event.content[Key.body], is: String.self)
        try self.expect(value: event.content[Key.messageType], is: String.self)

        try self.expect(value: event.content[Key.relatesTo], is: [String: Any]?.self)

        if let relatesTo = event.content[Key.relatesTo] as? [String: Any] {
            try self.expect(value: relatesTo[Key.RelatesTo.inReplyTo], is: [String: Any]?.self)

            if let inReplyTo = relatesTo[Key.RelatesTo.inReplyTo] as? [String: Any] {
                try self.validate(dictionary: inReplyTo, for: NIORoomMessageEventReplyRelationship.self)
            }
        }
    }
}
