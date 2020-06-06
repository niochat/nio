import XCTest

import SwiftMatrixSDK

@testable import NioKit

class NIORoomNameEventTests: XCTestCase {
    func testTyped() throws {
        typealias TypedEvent = NIORoomNameEvent

        let roomId = "!9876543210:example.org"
        let eventId = "$0123456789:example.org"
        let sender = "@example:example.org"
        let name = "Lorem ipsum"

        let eventOrNil = MXEvent(fromJSON: [
            "room_id": roomId,
            "event_id": eventId,
            "sender": sender,
            "type": "m.room.name",
            "state_key": "",
            "content": [
                "name": name,
            ]
        ])

        let anyTypedEvent = try XCTUnwrap(eventOrNil).typed()
        let typedEvent = try XCTUnwrap(anyTypedEvent as? TypedEvent)

        XCTAssertEqual(typedEvent.roomId, roomId)
        XCTAssertEqual(typedEvent.eventId, eventId)
        XCTAssertEqual(typedEvent.sender, sender)

        XCTAssertEqual(typedEvent.roomName, name)
    }
}
