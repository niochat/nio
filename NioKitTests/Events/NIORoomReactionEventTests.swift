import XCTest

import SwiftMatrixSDK

@testable import NioKit

class NIORoomReactionEventTests: XCTestCase {
    func testText() throws {
        typealias TypedEvent = NIORoomReactionEvent

        let roomId = "!9876543210:example.org"
        let eventId = "$0123456789:example.org"
        let sender = "@example:example.org"

        let key = "👍"
        let relType = "m.annotation"

        let relatedEventId = "$9876543210:example.org"

        let eventOrNil = MXEvent(fromJSON: [
            "room_id": roomId,
            "event_id": eventId,
            "sender": sender,
            "type": "m.reaction",
            "state_key": "",
            "content": [
                "m.relates_to": [
                    "rel_type": relType,
                    "event_id": relatedEventId,
                    "key": key,
                ],
            ]
        ])

        let anyTypedEvent = try XCTUnwrap(eventOrNil).typed()
        let typedEvent = try XCTUnwrap(anyTypedEvent as? TypedEvent)

        XCTAssertEqual(typedEvent.roomId, roomId)
        XCTAssertEqual(typedEvent.eventId, eventId)
        XCTAssertEqual(typedEvent.sender, sender)

        XCTAssertEqual(typedEvent.key, key)
        XCTAssertEqual(typedEvent.relatedEventId, relatedEventId)
        XCTAssertEqual(typedEvent.relType, relType)
    }
}
