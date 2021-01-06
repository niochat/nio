import Foundation
import MatrixSDK

protocol TypeableEvent {
    var type: String { get }
    var sender: String { get }
}

/// An event and its type
struct TypedEvent<Event> where Event: TypeableEvent {
    let type: MXEventType
    let event: Event
}

extension TypedEvent: Equatable where Event: Equatable {
    static func == (lhs: TypedEvent, rhs: TypedEvent) -> Bool {
        guard lhs.type == rhs.type else {
            return false
        }

        guard lhs.event == rhs.event else {
            return false
        }

        return true
    }
}

/// A non-empty group of homogeneous events
struct TypedEventGroup<Event> where Event: TypeableEvent {
    let type: MXEventType
    let events: [Event]

    init(type: MXEventType, events: [TypedEvent<Event>]) {
        let events = events.map { $0.event }
        self.init(type: type, events: events)
    }

    init(type: MXEventType, events: [Event]) {
        assert(!events.isEmpty)
        assert(events.allSatisfy { event in
            MXEventType(identifier: event.type) == type
        })

        self.type = type
        self.events = events
    }
}

extension TypedEventGroup: Equatable where Event: Equatable {
    static func == (lhs: TypedEventGroup, rhs: TypedEventGroup) -> Bool {
        lhs.events == rhs.events
    }
}

/// A collection of groups of events of equal type.
struct TypedEventGroups<Event>: Collection where Event: TypeableEvent {
    typealias Index = Int

    var startIndex: Int {
        0
    }

    var endIndex: Int {
        groups.count
    }

    let groups: [TypedEventGroup<Event>]

    init<S>(events: S) where S: Sequence, S.Element == Event {
        self.init(groups: Self.grouped(events: events))
    }

    init(groups: [TypedEventGroup<Event>]) {
        self.groups = groups
    }

    private static func grouped<S>(events: S) -> [TypedEventGroup<Event>] where S: Sequence, S.Element == Event {
        let typedEvents: LazyMapSequence<S, TypedEvent<Event>> = events.lazy.map { event in
            let type = MXEventType(identifier: event.type)
            return TypedEvent(type: type, event: event)
        }
        let iterator = typedEvents.makeIterator()
        let groupingIterator = GroupingIterator(iterator) { lhs, rhs in
            // Split the events into groups of consecutive events of same type:
            guard lhs.type == rhs.type else {
                return false
            }
            switch lhs.type {
            // Perform additional specialized grouping for message events:
            case .roomMessage, .roomMessageFeedback:
                // Groups into consecutive events of same sender:
                return lhs.event.sender == rhs.event.sender
            case _:
                return true
            }
        }
        let groups = IteratorSequence(groupingIterator)
        return groups.compactMap { events in
            guard let event = events.first else {
                return nil
            }
            return TypedEventGroup(type: event.type, events: events)
        }
    }

    subscript(position: Int) -> TypedEventGroup<Event> {
        groups[position]
    }

    func index(after index: Int) -> Int {
        index + 1
    }
}

extension TypedEventGroups: Equatable where Event: Equatable {
    static func == (lhs: TypedEventGroups, rhs: TypedEventGroups) -> Bool {
        lhs.groups == rhs.groups
    }
}
