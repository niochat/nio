import SwiftMatrixSDK

// MARK: - Reply

public protocol NIORoomMessageEventReplyRelationshipProtocol {
    /// The ID of the event that this event is in reply to.
    var eventId: String { get }
}

public struct NIORoomMessageEventReplyRelationship {
    fileprivate struct Key {
        static let eventId: String = "event_id"
    }

    private let dictionary: [String: Any]

    public init(fromJSON dictionary: [String: Any]) throws {
        try MXEventValidator.validate(dictionary: dictionary, for: Self.self)

        self.dictionary = dictionary
    }
}

extension NIORoomMessageEventReplyRelationship: NIORoomMessageEventReplyRelationshipProtocol {
    public var eventId: String {
        // swiftlint:disable:next force_cast
        self.dictionary[Key.eventId] as! String
    }
}

extension MXEventValidator {
    internal static func validate(dictionary: [String: Any], for: NIORoomMessageEventReplyRelationship.Type) throws {
        typealias Key = NIORoomMessageEventReplyRelationship.Key

        try self.expect(value: dictionary[Key.eventId], is: String.self)
    }
}
