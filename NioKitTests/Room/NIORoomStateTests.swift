import XCTest

import SwiftMatrixSDK

@testable import NioKit

class NIORoomStateTests: XCTestCase {
    enum Relationship {
        case reply(id: String)
        case replace(id: String)
        case reference(id: String)
    }

    func messageEvent(
        roomId: String = "!default:example.org",
        eventId: String,
        sender: String,
        body: String,
        relationship: Relationship? = nil,
        file: StaticString = #file,
        line: UInt = #line
    ) throws -> NIORoomMessageEvent {
        let relatesTo: [String: Any]? = relationship.map { relationship in
            switch relationship {
            case .reply(let relatedEventId):
                return [
                    "m.in_reply_to": [
                        "event_id": relatedEventId,
                    ],
                ]
            case .replace(let relatedEventId):
                return [
                    "rel_type": "m.replace",
                    "event_id": relatedEventId,
                ]
            case .reference(let relatedEventId):
                return [
                    "rel_type": "m.reference",
                    "event_id": relatedEventId,
                ]
            }
        }
        return try self.event(
            from: [
                "room_id": roomId,
                "event_id": eventId,
                "sender": sender,
                "type": "m.room.message",
                "state_key": "",
                "content": [
                    "body": body,
                    "msgtype": "m.text",
                    "m.relates_to": relatesTo as Any,
                ]
            ]
        )
    }

    func reactionEvent(
        roomId: String = "!default:example.org",
        eventId: String,
        sender: String,
        key: String,
        relatedEventId: String,
        file: StaticString = #file,
        line: UInt = #line
    ) throws -> NIORoomReactionEvent {
        try self.event(
            from: [
                "room_id": roomId,
                "event_id": eventId,
                "sender": sender,
                "type": "m.reaction",
                "state_key": "",
                "content": [
                    "m.relates_to": [
                        "rel_type": "m.annotation",
                        "event_id": relatedEventId,
                        "key": key,
                    ],
                ]
            ]
        )
    }

    func event<T>(
        from json: [String: Any],
        file: StaticString = #file,
        line: UInt = #line
    ) throws -> T {
        let eventOrNil = MXEvent(fromJSON: json)
        return try XCTUnwrap(eventOrNil?.typed() as? T, file: file, line: line)
    }

    func testRoomState() throws {
        let events: [NIORoomEventProtocol] = [
            try self.messageEvent(eventId: "1", sender: "Alice", body: "Holle World!"),
            try self.messageEvent(eventId: "2", sender: "Alice", body: "Hollo World!", relationship: .replace(id: "1")),
            try self.reactionEvent(eventId: "3", sender: "Bob", key: "💔", relatedEventId: "0"),
            try self.messageEvent(eventId: "4", sender: "Bob", body: "Lorem ipsum!"),
            try self.reactionEvent(eventId: "5", sender: "Eve", key: "❤️", relatedEventId: "1"),
            try self.messageEvent(eventId: "6", sender: "Alice", body: "Hello World!", relationship: .replace(id: "1")),
            try self.reactionEvent(eventId: "7", sender: "Alice", key: "❤️", relatedEventId: "1"),
//            .redact(.init(id: 8, age: 8, messageId: 4)),
        ]

        let roomState = NIORoomState()

        for event in events {
            try roomState.add(event: event)
        }

        for item in roomState.itemsByEventId {
            print("item:", item)
        }

        for stashedEvent in roomState.stashedEvents {
            print("stashed:", stashedEvent)
        }

        let expectedItemsByEventId: NIORoomState.ItemsByEventId = [
            "1": NIORoomMessageItem(
                eventId: "1",
                content: .init(sender: "Alice", body: "Hello World!"),
                reactions: ["❤️": ["Eve", "Alice"]]
            ),
            "4": NIORoomMessageItem(
                eventId: "4",
                content: .init(sender: "Bob", body: "Lorem ipsum!")
            ),
        ]
        let itemsByEventId = (
            actual: roomState.itemsByEventId,
            expected: expectedItemsByEventId
        )
        let eventIdsOfitemsByEventId = (
            actual: itemsByEventId.actual.keys.sorted(),
            expected: itemsByEventId.expected.keys.sorted()
        )
        XCTAssertEqual(eventIdsOfitemsByEventId.actual, eventIdsOfitemsByEventId.expected)
        for (actualKey, expectedKey) in zip(eventIdsOfitemsByEventId.actual, eventIdsOfitemsByEventId.expected) {
            let (actualValue, expectedValue) = (itemsByEventId.actual[actualKey]!, itemsByEventId.expected[expectedKey]!)
            switch (actualValue, expectedValue) {
            case let (actual as NIORoomMessageItem, expected as NIORoomMessageItem):
                XCTAssertEqual(actual, expected)
            case _:
                XCTFail("\(String(reflecting: type(of: actualValue))) != \(String(reflecting: type(of: expectedValue)))")
            }
        }

        let expectedStashedEvents: NIORoomState.StachedEventsByRelatedEventId = [
            "0": [try self.reactionEvent(eventId: "3", sender: "Bob", key: "💔", relatedEventId: "0")],
        ]
        let stashedEvents = (
            actual: roomState.stashedEvents,
            expected: expectedStashedEvents
        )
        let eventIdsOfStashedEvents = (
            actual: stashedEvents.actual.keys.sorted(),
            expected: stashedEvents.expected.keys.sorted()
        )
        XCTAssertEqual(eventIdsOfStashedEvents.actual, eventIdsOfStashedEvents.expected)
        for (actualKey, expectedKey) in zip(eventIdsOfStashedEvents.actual, eventIdsOfStashedEvents.expected) {
            let (actualValues, expectedValues) = (stashedEvents.actual[actualKey]!, stashedEvents.expected[expectedKey]!)
            for (actualValue, expectedValue) in zip(actualValues, expectedValues) {
                switch (actualValue, expectedValue) {
                case let (actual as NIORoomMessageEvent, expected as NIORoomMessageEvent):
                    XCTAssertEqual(actual, expected)
                case let (actual as NIORoomReactionEvent, expected as NIORoomReactionEvent):
                    XCTAssertEqual(actual, expected)
                case _:
                    XCTFail("")
                }
            }
        }
    }

//    func testRoomStateLoadHistory() throws {
//        let events: [Event] = [
//            .message(.init(id: 1, age: 1, body: "Holle World!")),
//            .edit(.init(id: 2, age: 2, messageId: 1, messageBody: "Hollo World!")),
//            .like(.init(id: 3, age: 3, messageId: 0)),
//            .message(.init(id: 4, age: 4, body: "Lorem ipsum!")),
//            .like(.init(id: 5, age: 5, messageId: 1)),
//            .edit(.init(id: 6, age: 6, messageId: 1, messageBody: "Hello World!")),
//            .like(.init(id: 7, age: 7, messageId: 1)),
//            .redact(.init(id: 8, age: 8, messageId: 4)),
//            .message(.init(id: 0, age: 0, body: "First!")),
//        ]
//
//        var roomState = RoomState()
//
//        for event in events {
//            try roomState.add(event: event).get()
//        }
//
//        for viewModelByEventId in roomState.viewModelsByEventId {
//            print("viewModelByEventId:", viewModelByEventId)
//        }
//
//        for eventIdByAge in roomState.eventIdsByAge {
//            print("eventIdByAge:", eventIdByAge)
//        }
//
//        for stashedEvent in roomState.stashedEvents {
//            print("stashedEvent:", stashedEvent)
//        }
//
//        let expected = RoomState(
//            viewModelsByEventId: [
//                0: .message(.init(id: 0, age: 0, body: "First!", likes: 1)),
//                1: .message(.init(id: 1, age: 1, body: "Hello World!", likes: 2)),
//                4: .tombstone(.init(id: 4, age: 4)),
//            ],
//            eventIdsByAge: [
//                .init(id: 0, age: 0),
//                .init(id: 1, age: 1),
//                .init(id: 4, age: 4),
//            ],
//            stashedEvents: [
//                :
//            ]
//        )
//
//        XCTAssertEqual(roomState, expected)
//    }

//    func testPerformanceExample() throws {
//        // This is an example of a performance test case.
//        self.measure {
//            // Put the code you want to measure the time of here.
//        }
//    }
}
