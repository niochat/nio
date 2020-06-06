import SwiftMatrixSDK

public protocol NIORoomTopicEventProtocol: NIORoomStateEventProtocol {
    /// The topic text.
    var roomTopic: String { get }
}

/// Room Topic Event \
/// ([API Schema](https://github.com/matrix-org/matrix-doc/blob/master/event-schemas/schema/m.room.topic))
///
/// A topic is a short message detailing what is currently being discussed in the room.
/// It can also be used as a way to display extra information about the room,
/// which may not be suitable for the room name.
/// The room topic can also be set when creating a room using ``/createRoom`` with the ``topic`` key.
public struct NIORoomTopicEvent: MXEventInitializable, MXEventProvider {
    fileprivate struct Key {
        static let type: String = "type"
        static let stateKey: String = "state_key"
        static let roomTopic: String = "topic"
    }

    public let event: MXEvent

    public init(event: MXEvent) throws {
        try MXEventValidator.validate(event: event, for: Self.self)

        self.event = event
    }
}

extension NIORoomTopicEvent: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        guard (lhs as NIORoomStateEventProtocol) == (rhs as NIORoomStateEventProtocol) else {
            return false
        }
        guard lhs.roomTopic == rhs.roomTopic else {
            return false
        }
        return true
    }
}

extension NIORoomTopicEvent: NIORoomTopicEventProtocol {
    public var roomTopic: String {
        // swiftlint:disable:next force_cast
        return self.content[Key.roomTopic] as! String
    }
}

extension MXEventValidator {
    internal static func validate(event: MXEvent, for: NIORoomTopicEvent.Type) throws {
        typealias Key = NIORoomTopicEvent.Key

        try self.validate(event: event, for: NIORoomStateEventProtocol.self)

        try self.expect(value: event.type, equals: "m.room.topic")
        try self.expect(value: event.stateKey, equals: "")

        try self.expect(value: event.content[Key.roomTopic], is: String.self)
    }
}
