import SwiftMatrixSDK

public protocol NIORoomReactionEventProtocol: NIORoomStateEventProtocol {
    /// The ID of the event that this event is reacting to.
    var relatedEventId: String { get }

    /// The key of the event.
    var key: String { get }

    /// The ID of the event that this event is reacting to.
    var relType: String { get }
}

/// Room Topic Event \
/// ([API Schema](https://github.com/matrix-org/matrix-doc/blob/master/event-schemas/schema/m.room.topic))
///
/// A topic is a short message detailing what is currently being discussed in the room.
/// It can also be used as a way to display extra information about the room,
/// which may not be suitable for the room name.
/// The room topic can also be set when creating a room using ``/createRoom`` with the ``topic`` key.
public struct NIORoomReactionEvent: MXEventInitializable, MXEventProvider {
    fileprivate struct Key {
        fileprivate struct Content {
            static let relatesTo: String = "m.relates_to"
            fileprivate struct RelatesTo {
                static let eventId: String = "event_id"
                static let key: String = "key"
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

extension NIORoomReactionEvent: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        guard (lhs as NIORoomStateEventProtocol) == (rhs as NIORoomStateEventProtocol) else {
            return false
        }
        guard lhs.relatedEventId == rhs.relatedEventId else {
            return false
        }
        guard lhs.key == rhs.key else {
            return false
        }
        guard lhs.relType == rhs.relType else {
            return false
        }
        return true
    }
}

extension NIORoomReactionEvent: NIORoomStateEventProtocol {}

extension NIORoomReactionEvent: NIORoomReactionEventProtocol {
    public var relatedEventId: String {
        // swiftlint:disable:next force_cast
        return self.relatesTo[Key.Content.RelatesTo.eventId] as! String
    }

    public var key: String {
        // swiftlint:disable:next force_cast
        return self.relatesTo[Key.Content.RelatesTo.key] as! String
    }

    public var relType: String {
        // swiftlint:disable:next force_cast
        return self.relatesTo[Key.Content.RelatesTo.relType] as! String
    }
}

extension NIORoomReactionEvent {
    private var relatesTo: [String: Any] {
        // swiftlint:disable:next force_cast
        return self.content[Key.Content.relatesTo] as! [String: Any]
    }
}

extension MXEventValidator {
    internal static func validate(event: MXEvent, for: NIORoomReactionEvent.Type) throws {
        typealias Key = NIORoomReactionEvent.Key

        try self.validate(event: event, for: NIORoomStateEventProtocol.self)

        try self.expect(value: event.type, equals: "m.reaction")
        try self.expect(value: event.stateKey, equals: "")

        let relatesTo = try self.unwrap(value: event.content[Key.Content.relatesTo], as: [String: Any].self)

        try self.expect(value: relatesTo[Key.Content.RelatesTo.eventId], is: String.self)
        try self.expect(value: relatesTo[Key.Content.RelatesTo.key], is: String.self)
        try self.expect(value: relatesTo[Key.Content.RelatesTo.relType], is: String.self)
    }
}
