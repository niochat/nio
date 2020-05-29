import XCTest

import SwiftMatrixSDK

@testable import NioKit

class NIORoomNameEventTests: XCTestCase {
    func testTyped() throws {
        typealias TypedEvent = NIORoomNameEvent

        let id = "$123456789012PhrSn:example.org"
        let sender = "@example:example.org"
        let name = "Lorem ipsum"

        let eventOrNil = MXEvent(fromJSON: [
            "event_id": id,
            "sender": sender,
            "type": "m.room.name",
            "state_key": "",
            "content": [
                "name": name,
            ]
        ])

        let anyTypedEvent = try XCTUnwrap(eventOrNil).typed()
        let typedEvent = try XCTUnwrap(anyTypedEvent as? TypedEvent)

        XCTAssertEqual(typedEvent.id, id)
        XCTAssertEqual(typedEvent.sender, sender)

        XCTAssertEqual(typedEvent.roomName, name)
    }
}
