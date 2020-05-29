import XCTest

import SwiftMatrixSDK

@testable import NioKit

class NIORoomTopicEventTests: XCTestCase {
    func testTyped() throws {
        typealias TypedEvent = NIORoomTopicEvent

        let id = "$123456789012PhrSn:example.org"
        let sender = "@example:example.org"
        let topic = "Lorem ipsum"

        let eventOrNil = MXEvent(fromJSON: [
            "event_id": id,
            "sender": sender,
            "type": "m.room.topic",
            "state_key": "",
            "content": [
                "topic": topic,
            ]
        ])

        let anyTypedEvent = try XCTUnwrap(eventOrNil).typed()
        let typedEvent = try XCTUnwrap(anyTypedEvent as? TypedEvent)

        XCTAssertEqual(typedEvent.id, id)
        XCTAssertEqual(typedEvent.sender, sender)
        
        XCTAssertEqual(typedEvent.roomTopic, topic)
    }
}
