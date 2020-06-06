import SwiftMatrixSDK

public protocol NIORoomMessageEventProtocol: NIORoomStateEventProtocol {
    /// The textual representation of this message.
    var body: String { get }

    // FIXME: promote to an enum?
    /// The type of message, e.g. ``m.image``, ``m.text``
    var messageType: String { get }

    var relationships: AnyCollection<NIORoomMessageEventRelationship>? { get }
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
            struct InReplyTo {
                static let eventId: String = "event_id"
            }

            struct Anonymous {
                static let eventId: String = "event_id"
                static let relType: String = "rel_type"
            }
        }
    }

    public let event: MXEvent

    public init(event: MXEvent) throws {
        try MXEventValidator.validate(event: event, for: Self.self)

        self.event = event
    }
}

extension NIORoomMessageEvent: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        guard (lhs as NIORoomStateEventProtocol) == (rhs as NIORoomStateEventProtocol) else {
            return false
        }
        guard lhs.body == rhs.body else {
            return false
        }
        guard lhs.messageType == rhs.messageType else {
            return false
        }
        guard lhs.relationships?.count == rhs.relationships?.count else {
            return false
        }
        if case let (lhs?, rhs?) = (lhs.relationships, rhs.relationships) {
            guard zip(lhs, rhs).allSatisfy({ $0 == $1 }) else {
                return false
            }
        }
        return true
    }
}

extension NIORoomMessageEvent: NIORoomEventProtocol {}

extension NIORoomMessageEvent: NIORoomMessageEventProtocol {
    public var body: String {
        // swiftlint:disable:next force_cast
        return self.content[Key.body] as! String
    }

    public var messageType: String {
        // swiftlint:disable:next force_cast
        return self.content[Key.messageType] as! String
    }

    public var relationships: AnyCollection<NIORoomMessageEventRelationship>? {
        guard let json = self.event.content[Key.relatesTo] as? [String: Any] else {
            return nil
        }

        var relationships: [NIORoomMessageEventRelationship] = []

        reply: if let inReplyTo = json[Key.RelatesTo.inReplyTo] as? [String: Any] {
            guard let eventId = inReplyTo[Key.RelatesTo.InReplyTo.eventId] as? String else {
                break reply
            }
            relationships.append(NIORoomMessageEventRelationship.reply(eventId: eventId))
        }

        anonymous: if let relType = json[Key.RelatesTo.Anonymous.relType] as? String {
            guard let eventId = json[Key.RelatesTo.Anonymous.eventId] as? String else {
                break anonymous
            }
            switch relType {
            case "m.replace":
                relationships.append(NIORoomMessageEventRelationship.replace(eventId: eventId))
            case "m.reference":
                relationships.append(NIORoomMessageEventRelationship.reference(eventId: eventId))
            case _:
                print("Ignoring relationship")
            }
        }

        return AnyCollection(relationships)
    }
}

extension MXEventValidator {
    internal static func validate(event: MXEvent, for: NIORoomMessageEvent.Type) throws {
        typealias Key = NIORoomMessageEvent.Key

        try self.validate(event: event, for: NIOSyncStateEventProtocol.self)

        try self.expect(value: event.type, equals: "m.room.message")

        try self.expect(value: event.content[Key.body], is: String.self)
        try self.expect(value: event.content[Key.messageType], is: String.self)

        try self.ifPresent(event.content[Key.relatesTo], as: [String: Any].self) { relatesTo in
            try self.ifPresent(relatesTo[Key.RelatesTo.inReplyTo], as: [String: Any].self) { inReplyTo in
                try self.expect(value: inReplyTo[Key.RelatesTo.InReplyTo.eventId], is: String.self)
            }
        }
    }
}
