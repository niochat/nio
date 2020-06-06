import Combine

import SwiftMatrixSDK

public typealias NIORoomStateItemID = String
public typealias NIORoomStateEventID = String

public class NIORoomState {
    public typealias EventProtocol = NIORoomEventProtocol
    public typealias ItemProtocol = NIORoomStateItemProtocol

    public typealias ItemID = String
    public typealias EventID = String

    public enum Error: Swift.Error {

    }

    internal enum EventKind {
        case root
        case modifier
    }

    internal struct EventIdByTimestamp: Equatable {
        let id: String
        let timestamp: UInt64
    }

    typealias ItemsByEventId = [ItemID: ItemProtocol]
    typealias StachedEventsByRelatedEventId = [EventID: [EventProtocol]]

    internal typealias EventIdsByTimestamp = [EventIdByTimestamp]

    public var items: CurrentValueSubject<[ItemProtocol], Error> = .init([])

    internal private(set) var itemsByEventId: ItemsByEventId
    internal private(set) var stashedEvents: StachedEventsByRelatedEventId
    internal private(set) var eventIdsByTimestamp: EventIdsByTimestamp

    public convenience init() {
        self.init(
            itemsByEventId: [:],
            eventIdsByTimestamp: [],
            stashedEvents: [:]
        )
    }

    public convenience init<S>(events: S) throws
    where
        S: Sequence,
        S.Element == EventProtocol
    {
        self.init(
            itemsByEventId: [:],
            eventIdsByTimestamp: [],
            stashedEvents: [:]
        )

        for event in events {
            try self.add(event: event)
        }
    }

    private init(
        itemsByEventId: ItemsByEventId,
        eventIdsByTimestamp: EventIdsByTimestamp,
        stashedEvents: StachedEventsByRelatedEventId
    ) {
        assert(itemsByEventId.count == eventIdsByTimestamp.count)
        self.itemsByEventId = itemsByEventId
        self.eventIdsByTimestamp = eventIdsByTimestamp
        self.stashedEvents = stashedEvents
    }

    func add(event: EventProtocol) throws {
        switch event {
        case let event as NIORoomMessageEventProtocol:
            try self.add(messageEvent: event)
        case let event as NIORoomReactionEventProtocol:
            try self.add(reactionEvent: event)
        case _:
            print("Ignoring event of unknown type \(String(reflecting: type(of: event)))")
        }
    }

    func add(messageEvent event: NIORoomMessageEventProtocol) throws {
        guard let relationships = event.relationships else {
            // If the event doesn't have a relationship, then it's a plain old message,
            // which means we can just add an item for it to the state:
            let item = NIORoomMessageItem(
                eventId: event.eventId,
                content: .init(
                    sender: event.sender,
                    body: event.body
                )
            )
            try self.add(item: item, forEvent: event)
            return
        }

        for relationship in relationships {
            switch relationship {
            case .reply(eventId: let eventId):
                // If the event has a `.reply` relationship, then we attach the replied-to item's sender and body
                // to the event's item, so it can be displayed without an additional lookup:
                guard let repliedEventItem = self.itemsByEventId[eventId] as? NIORoomMessageItem else {
                    continue
                }
                let item = NIORoomMessageItem(
                    eventId: event.eventId,
                    content: .init(
                        sender: event.sender,
                        body: event.body
                    ),
                    repliedTo: .init(
                        id: eventId,
                        content: repliedEventItem.content
                    )
                )
                try self.add(item: item, forEvent: event)
            case .replace(eventId: let eventId):
                // If the event has a `.replace` relationship, then we replace the replaced item's content:
                guard var replacedEventItem = self.itemsByEventId[eventId] as? NIORoomMessageItem else {
                    continue
                }
                replacedEventItem.content.body = event.body
                self.itemsByEventId[eventId] = replacedEventItem
            case .reference(eventId: let eventId):
                let item = NIORoomMessageItem(
                    eventId: event.eventId,
                    content: .init(
                        sender: event.sender,
                        body: event.body
                    ),
                    referenced: .init(id: eventId)
                )
                try self.add(item: item, forEvent: event)
            }
        }
    }

    func add(reactionEvent event: NIORoomReactionEventProtocol) throws {
        let relatedEventId = event.relatedEventId
        guard var relatedEventItem = self.itemsByEventId[relatedEventId] as? NIORoomMessageItem else {
            self.stash(event: event, relatedTo: relatedEventId)
            return
        }

        var reactions = relatedEventItem.reactions ?? .init()

        reactions.individual[event.key, default: []].append(event.sender)
        relatedEventItem.reactions = reactions

        self.itemsByEventId[relatedEventId] = relatedEventItem
    }

    internal func add(item: NIORoomStateItemProtocol, forEvent event: EventProtocol) throws {
        guard self.itemsByEventId[event.eventId] == nil else {
            print("Ignored redundant event")
            return
        }
        self.itemsByEventId[event.eventId] = item
        let insertionIndex = self.eventIdsByTimestamp.insertionIndex(
            of: event.originServerTs,
            keyPath: \.timestamp
        )
        let eventIdByTimestamp = EventIdByTimestamp(id: event.eventId, timestamp: event.originServerTs)
        self.eventIdsByTimestamp.insert(eventIdByTimestamp, at: insertionIndex)
        try self.replayStashedEvents(event: event)
    }

    internal func replayStashedEvents(event: EventProtocol) throws {
        guard var stashedEvents = self.stashedEvents.removeValue(forKey: event.eventId) else {
            return
        }

        stashedEvents.sort { $0.originServerTs < $1.originServerTs }

        for stashedEvent in stashedEvents {
            try self.add(event: stashedEvent)
        }
    }

    private func stash(event: EventProtocol, relatedTo id: EventID) {
        self.stashedEvents[id, default: []].append(event)
    }
}
