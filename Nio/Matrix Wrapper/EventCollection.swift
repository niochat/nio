import Foundation
import SwiftMatrixSDK

struct EventCollection {
    var wrapped: [MXEvent]

    var renderableEvents: [MXEvent] {
        let renderableEventTypes = [
            kMXEventTypeStringRoomMessage,
            kMXEventTypeStringRoomMember,
            kMXEventTypeStringRoomTopic
        ]
        return wrapped.filter { renderableEventTypes.contains($0.type) }
    }

    init(_ events: [MXEvent]) {
        self.wrapped = events
    }

    func connectedEdges(of event: MXEvent) -> ConnectedEdges {
        guard let idx = wrapped.firstIndex(of: event) else {
            fatalError("Event not found in EventCollection")
        }

        guard idx > wrapped.startIndex else {
            return .bottomEdge
        }

        guard
            let sender = event.sender,
            let preSender = wrapped[wrapped.index(before: idx)].sender
        else {
            return []
        }

        if sender != preSender {
            return .bottomEdge
        }

        guard
            idx < wrapped.endIndex - 1,
            let sucSender = wrapped[wrapped.index(after: idx)].sender
        else {
            return .topEdge
        }

        if sender != sucSender {
            return .topEdge
        } else if sender == preSender && sender != sucSender {
            return .topEdge
        } else if sender == preSender && sender == sucSender {
            return [.topEdge, .bottomEdge]
        }

        fatalError("Non-covered position case? \(sender) \(preSender) \(sucSender)")
    }

    func relatedEvents(of event: MXEvent) -> [MXEvent] {
        wrapped.filter { $0.relatesTo?.eventId == event.eventId }
    }

    // FIXME: For the love of god...
    func reactions(for event: MXEvent) -> [String] {
        relatedEvents(of: event)
            .filter { $0.type == kMXEventTypeStringReaction }
            .compactMap { ($0.content["m.relates_to"] as? [String: Any])?["key"] as? String }
    }
}

struct ConnectedEdges: OptionSet {
    let rawValue: Int

    static let topEdge: Self = .init(rawValue: 1 << 0)
    static let bottomEdge: Self = .init(rawValue: 1 << 1)
}
