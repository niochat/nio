import Foundation
import SwiftMatrixSDK

struct EventCollection {
    var wrapped: [MXEvent]

    init(_ events: [MXEvent]) {
        self.wrapped = events
    }

    static let renderableEventTypes = [
        kMXEventTypeStringRoomMessage,
        kMXEventTypeStringRoomMember,
        kMXEventTypeStringRoomTopic
    ]

    /// Events that can be directly rendered in the timeline with a corresponding view. This for example does not include reactions, which are instead rendered
    /// as accessories on their corresponding related events.
    var renderableEvents: [MXEvent] {
        wrapped.filter { Self.renderableEventTypes.contains($0.type) }
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

// MARK: Grouping

extension EventCollection {
    static let groupableEventTypes = [
        kMXEventTypeStringRoomMessage,
    ]

    func connectedEdges(of event: MXEvent) -> ConnectedEdges {
        guard let idx = wrapped.firstIndex(of: event) else {
            fatalError("Event not found in event collection.")
        }

        guard idx >= wrapped.startIndex else {
            return []
        }

        // Note to self: `first(where:)` should not filter redacted messages here, since that would skip them and base
        // the decision on the message event before that, possibly wrapping the redaction inside the group. Redacted
        // state is checked separately.
        let precedingMessageEvent = wrapped[..<idx]
            .reversed()
            .first { Self.groupableEventTypes.contains($0.type) }

        let succeedingMessageEvent = wrapped[wrapped.index(after: idx)...]
            .first { Self.groupableEventTypes.contains($0.type) }

        let isPrecedingRedacted = precedingMessageEvent?.isRedactedEvent() ?? false
        let isSucceedingRedacted = succeedingMessageEvent?.isRedactedEvent() ?? false

        // If a message is sent within this time interval, it is considered to be part of the current group.
        let timeIntervalBeforeNewGroup: TimeInterval = 3*60
        let precedingInterval = precedingMessageEvent.map { event.timestamp.timeIntervalSince($0.timestamp) } ?? 10000
        let succeedingInterval = succeedingMessageEvent?.timestamp.timeIntervalSince(event.timestamp) ?? 10000

        let groupedWithPreceding = event.sender == precedingMessageEvent?.sender
            && !isPrecedingRedacted
            && precedingInterval < timeIntervalBeforeNewGroup

        let groupedWithSucceeding = event.sender == succeedingMessageEvent?.sender
            && !isSucceedingRedacted
            && succeedingInterval < timeIntervalBeforeNewGroup

        switch (groupedWithPreceding, groupedWithSucceeding) {
        case (false, false):
            return []
        case (true, false):
            return .topEdge
        case (false, true):
            return .bottomEdge
        case (true, true):
            return [.topEdge, .bottomEdge]
        }
    }
}

struct ConnectedEdges: OptionSet {
    let rawValue: Int

    static let topEdge: Self = .init(rawValue: 1 << 0)
    static let bottomEdge: Self = .init(rawValue: 1 << 1)
}
