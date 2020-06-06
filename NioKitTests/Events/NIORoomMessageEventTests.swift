import XCTest

import SwiftMatrixSDK

@testable import NioKit

class NIORoomMessageEventTests: XCTestCase {
    func testText() throws {
        typealias TypedEvent = NIORoomMessageEvent

        let roomId = "!9876543210:example.org"
        let eventId = "$0123456789:example.org"
        let sender = "@example:example.org"

        let body = "Lorem ipsum!"
        let messageType = "m.text"

        let eventOrNil = MXEvent(fromJSON: [
            "room_id": roomId,
            "event_id": eventId,
            "sender": sender,
            "type": "m.room.message",
            "state_key": "",
            "content": [
                "body": body,
                "msgtype": messageType,
            ]
        ])

        let anyTypedEvent = try XCTUnwrap(eventOrNil).typed()
        let typedEvent = try XCTUnwrap(anyTypedEvent as? TypedEvent)

        XCTAssertEqual(typedEvent.eventId, eventId)
        XCTAssertEqual(typedEvent.sender, sender)

        XCTAssertEqual(typedEvent.body, body)
        XCTAssertEqual(typedEvent.messageType, messageType)
    }

    func testReply() throws {
        typealias TypedEvent = NIORoomMessageEvent
        typealias TypedRelationship = NIORoomMessageEventRelationship

        let roomId = "!9876543210:example.org"
        let eventId = "$0123456789:example.org"
        let sender = "@example:example.org"

        let body = "Lorem ipsum!"
        let messageType = "m.text"

        let relatedEventId = "$9876543210:example.org"

        let eventOrNil = MXEvent(fromJSON: [
            "room_id": roomId,
            "event_id": eventId,
            "sender": sender,
            "type": "m.room.message",
            "state_key": "",
            "content": [
                "body": body,
                "msgtype": messageType,
                "m.relates_to": [
                    "m.in_reply_to": [
                        "event_id": relatedEventId,
                    ],
                ],
            ]
        ])

        let anyTypedEvent = try XCTUnwrap(eventOrNil).typed()
        let typedEvent = try XCTUnwrap(anyTypedEvent as? TypedEvent)

        XCTAssertEqual(typedEvent.eventId, eventId)
        XCTAssertEqual(typedEvent.sender, sender)

        XCTAssertEqual(typedEvent.body, body)
        XCTAssertEqual(typedEvent.messageType, messageType)

        XCTAssertEqual(typedEvent.relationships.map { Array($0) }, [
            TypedRelationship.reply(eventId: relatedEventId),
        ])
    }

    func testReplace() throws {
        typealias TypedEvent = NIORoomMessageEvent
        typealias TypedRelationship = NIORoomMessageEventRelationship

        let roomId = "!9876543210:example.org"
        let eventId = "$0123456789:example.org"
        let sender = "@example:example.org"

        let body = "Lorem ipsum!"
        let messageType = "m.text"

        let relatedEventId = "$9876543210:example.org"

        let eventOrNil = MXEvent(fromJSON: [
            "room_id": roomId,
            "event_id": eventId,
            "sender": sender,
            "type": "m.room.message",
            "state_key": "",
            "content": [
                "body": body,
                "msgtype": messageType,
                "m.relates_to": [
                    "rel_type": "m.replace",
                    "event_id": relatedEventId,
                ],
            ]
        ])

        let anyTypedEvent = try XCTUnwrap(eventOrNil).typed()
        let typedEvent = try XCTUnwrap(anyTypedEvent as? TypedEvent)

        XCTAssertEqual(typedEvent.roomId, roomId)
        XCTAssertEqual(typedEvent.eventId, eventId)
        XCTAssertEqual(typedEvent.sender, sender)

        XCTAssertEqual(typedEvent.body, body)
        XCTAssertEqual(typedEvent.messageType, messageType)

        XCTAssertEqual(typedEvent.relationships.map { Array($0) }, [
            TypedRelationship.replace(eventId: relatedEventId),
        ])
    }
}
