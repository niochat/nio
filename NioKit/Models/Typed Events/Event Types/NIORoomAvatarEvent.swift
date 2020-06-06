import SwiftMatrixSDK

public protocol NIORoomAvatarEventProtocol: NIORoomStateEventProtocol {
    /// The URL to the image.
    var avatarURL: URL { get }

    /// Metadata about the image referred to in ``url``.
    var avatarInfo: NIOImageInfo? { get }
}

/// Room Avatar Event \
/// ([API Schema](https://github.com/matrix-org/matrix-doc/blob/master/event-schemas/schema/m.room.avatar))
///
/// A avatar is a short message detailing what is currently being discussed in the room.
/// It can also be used as a way to display extra information about the room,
/// which may not be suitable for the room name.
/// The room avatar can also be set when creating a room using ``/createRoom`` with the ``avatar`` key.
public struct NIORoomAvatarEvent: MXEventInitializable, MXEventProvider {
    fileprivate struct Key {
        static let url: String = "url"
        static let info: String = "info"
    }

    public let event: MXEvent

    public init(event: MXEvent) throws {
        try MXEventValidator.validate(event: event, for: Self.self)

        self.event = event
    }
}

extension NIORoomAvatarEvent: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        guard (lhs as NIORoomStateEventProtocol) == (rhs as NIORoomStateEventProtocol) else {
            return false
        }
        guard lhs.avatarURL == rhs.avatarURL else {
            return false
        }
        guard lhs.avatarInfo == rhs.avatarInfo else {
            return false
        }
        return true
    }
}

extension NIORoomAvatarEvent: NIORoomAvatarEventProtocol {
    public var avatarURL: URL {
        // swiftlint:disable:next force_cast
        let urlString = self.content[Key.url] as! String
        return URL(string: urlString)!
    }

    public var avatarInfo: NIOImageInfo? {
        // swiftlint:disable:next force_cast
        let dictionary = self.event.content[Key.info] as! [String: Any]

        // swiftlint:disable:next force_try
        return try! NIOImageInfo(fromJSON: dictionary)
    }
}

extension MXEventValidator {
    internal static func validate(event: MXEvent, for: NIORoomAvatarEvent.Type) throws {
        typealias Key = NIORoomAvatarEvent.Key

        try self.validate(event: event, for: NIORoomStateEventProtocol.self)

        try self.expect(value: event.type, equals: "m.room.avatar")
        try self.expect(value: event.stateKey, equals: "")

        try self.expect(value: event.content[Key.url], is: String.self)

        try self.ifPresent(event.content[Key.info], as: [String: Any].self) { info in
            try MXEventValidator.validate(dictionary: info, for: NIOImageInfo.self)
        }
    }
}
