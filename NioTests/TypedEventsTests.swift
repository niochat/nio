import XCTest
import SwiftMatrixSDK

@testable import Nio

class TypedEventsTests: XCTestCase {
    struct Event: TypeableEvent, Equatable {
        let id: Int
        let type: String
        let sender: String

        public init(id: Int, type: MXEventType, sender: String) {
            self.id = id
            self.type = type.identifier
            self.sender = sender
        }
    }

    func testGroupHomogeneousMessages() {
        let events: [Event] = [
            Event(id: 0, type: .roomMessage, sender: "Alice"),
            Event(id: 1, type: .roomMessage, sender: "Alice"),
            Event(id: 2, type: .roomMessage, sender: "Bob"),
            Event(id: 3, type: .roomMessage, sender: "Eve"),
            Event(id: 4, type: .roomMessage, sender: "Eve"),
            Event(id: 5, type: .roomMessage, sender: "Bob")
        ]

        let actual = TypedEventGroups(events: events)
        let expected: TypedEventGroups<Event> = TypedEventGroups(groups: [
            TypedEventGroup(type: .roomMessage, events: [
                Event(id: 0, type: .roomMessage, sender: "Alice"),
                Event(id: 1, type: .roomMessage, sender: "Alice")
            ]),
            TypedEventGroup(type: .roomMessage, events: [
                Event(id: 2, type: .roomMessage, sender: "Bob")
            ]),
            TypedEventGroup(type: .roomMessage, events: [
                Event(id: 3, type: .roomMessage, sender: "Eve"),
                Event(id: 4, type: .roomMessage, sender: "Eve")
            ]),
            TypedEventGroup(type: .roomMessage, events: [
                Event(id: 5, type: .roomMessage, sender: "Bob")
            ])
        ])

        XCTAssertEqual(actual, expected)
    }

    func testGroupHeterogeneousEvents() {
        let events: [Event] = [
            Event(id: 0, type: .roomMessage, sender: "Alice"),
            Event(id: 1, type: .roomMessage, sender: "Alice"),
            Event(id: 2, type: .presence, sender: "Alice"),
            Event(id: 3, type: .roomMessage, sender: "Eve"),
            Event(id: 4, type: .roomMessage, sender: "Eve"),
            Event(id: 5, type: .roomMessage, sender: "Bob")
        ]

        let actual = TypedEventGroups(events: events)
        let expected: TypedEventGroups<Event> = TypedEventGroups(groups: [
            TypedEventGroup(type: .roomMessage, events: [
                Event(id: 0, type: .roomMessage, sender: "Alice"),
                Event(id: 1, type: .roomMessage, sender: "Alice")
            ]),
            TypedEventGroup(type: .presence, events: [
                Event(id: 2, type: .presence, sender: "Alice")
            ]),
            TypedEventGroup(type: .roomMessage, events: [
                Event(id: 3, type: .roomMessage, sender: "Eve"),
                Event(id: 4, type: .roomMessage, sender: "Eve")
            ]),
            TypedEventGroup(type: .roomMessage, events: [
                Event(id: 5, type: .roomMessage, sender: "Bob")
            ])
        ])

        XCTAssertEqual(actual, expected)
    }
}
