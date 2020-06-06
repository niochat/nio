import SwiftMatrixSDK

// MARK: - Reply

public protocol NIORoomMessageEventRelationshipProtocol {
    /// The ID of the event that this event is related to.
    var eventId: String { get }
}

public enum NIORoomMessageEventRelationship {
    case reply(eventId: String)
    case replace(eventId: String)
    case reference(eventId: String)
}

extension NIORoomMessageEventRelationship: Equatable {}

extension NIORoomMessageEventRelationship: NIORoomMessageEventRelationshipProtocol {
    public var eventId: String {
        switch self {
        case .reply(let eventId): return eventId
        case .replace(let eventId): return eventId
        case .reference(let eventId): return eventId
        }
    }
}
