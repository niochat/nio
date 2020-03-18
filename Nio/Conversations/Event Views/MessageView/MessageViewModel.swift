import SwiftMatrixSDK

protocol MessageViewModelProtocol {
    var id: String { get }
    var text: String { get }
    var sender: String { get }
    var timestamp: String { get }
}

extension MessageViewModelProtocol {
    var isEmoji: Bool {
        (text.count <= 3) && text.containsOnlyEmoji
    }
}

struct MessageViewModel: MessageViewModelProtocol {
    enum Error: Swift.Error {
        case invalidEventType(MXEventType)

        var localizedDescription: String {
            switch self {
            case .invalidEventType(let type):
                return "Expected message event, found \(type)"
            }
        }
    }

    var id: String {
        event.eventId
    }

    var text: String {
        return (event.content["body"] as? String).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        } ?? "Error: expected string body"
    }

    var sender: String {
        event.sender
    }

    var timestamp: String {
        Formatter.string(for: event.timestamp, timeStyle: .short)
    }

    private let event: MXEvent

    public init(event: MXEvent) throws {
        try Self.validate(event: event)

        self.event = event
    }

    private static func validate(event: MXEvent) throws {
        let eventType = MXEventType(identifier: event.type)
        // FIXME: Replace with simple `eventType == .roomMessage`
        // once https://github.com/matrix-org/matrix-ios-sdk/pull/755 is part of a release (presumably v0.15.3):

        guard case .roomMessage = eventType else {
            throw Error.invalidEventType(eventType)
        }
    }
}
