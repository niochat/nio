import Foundation
import SwiftMatrixSDK

struct GroupBounds: OptionSet, Equatable, Hashable {
    let rawValue: Int

    static let before: Self = .init(rawValue: 1 << 0)
    static let after: Self = .init(rawValue: 1 << 1)

    static let both: Self = [.before, .after]
}

struct Bounded<Wrapped> {
    var wrapped: Wrapped
    var bounds: GroupBounds

    init(_ wrapped: Wrapped, bounds: GroupBounds) {
        self.wrapped = wrapped
        self.bounds = bounds
    }
}

extension Bounded: Equatable where Wrapped: Equatable {}

extension Bounded: Hashable where Wrapped: Hashable {}

extension Bounded: Identifiable where Wrapped: Identifiable {
    // swiftlint:disable:next type_name
    typealias ID = Wrapped.ID

    var id: ID {
        wrapped.id
    }
}

extension Bounded where Wrapped == MXEvent {
    var event: MXEvent {
        get { wrapped }
        set { wrapped = newValue }
    }
}

struct EventGroup {
    let events: [MXEvent]

    init(_ events: [MXEvent] = []) {
        self.events = events
    }
}

struct EventGroups {
    var groups: [EventGroup]

    init(_ events: [MXEvent]) {
        self.groups = Self.groups(from: events)
    }

    // Collects events in groups of equal `.sender`:
    static func groups<S>(from events: S) -> [EventGroup] where S: Sequence, S.Element == MXEvent {
        let iterator = events.makeIterator()
        let groupingIterator = GroupingIterator(iterator) { $0.sender }
        return IteratorSequence(groupingIterator).map { EventGroup($0) }
    }
}
