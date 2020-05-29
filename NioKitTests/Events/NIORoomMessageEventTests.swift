import XCTest

import SwiftMatrixSDK

@testable import NioKit

class NIORoomMessageEventTests: XCTestCase {
    func testTyped() throws {
        typealias TypedEvent = NIORoomMessageEvent

        let eventId = "$123456789012PhrSn:example.org"
        let sender = "@example:example.org"

        let body = "Lorem ipsum!"
        let messageType = "m.text"

        let eventOrNil = MXEvent(fromJSON: [
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
}
