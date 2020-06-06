import XCTest

import SwiftMatrixSDK

@testable import NioKit

class NIORoomAvatarEventTests: XCTestCase {
    func testTyped() throws {
        typealias TypedEvent = NIORoomAvatarEvent

        let roomId = "!9876543210:example.org"
        let eventId = "$0123456789:example.org"
        let sender = "@example:example.org"

        let urlString = "https://example.org/avatar.png"

        let infoHeight = 123
        let infoWidth = 456
        let infoMimeType = ""
        let infoSize = 1234
        let infoThumbnailURL = urlString
//        let infoThumbnailFile = ""
//        let infoThumbnailInfo = ""

        let eventOrNil = MXEvent(fromJSON: [
            "room_id": roomId,
            "event_id": eventId,
            "sender": sender,
            "type": "m.room.avatar",
            "state_key": "",
            "content": [
                "url": urlString,
                "info": [
                    "h": "\(infoHeight)",
                    "w": "\(infoWidth)",
                    "mimetype": infoMimeType,
                    "size": "\(infoSize)",
                    "thumbnail_url": infoThumbnailURL,
//                    "thumbnail_file": infoThumbnailFile,
//                    "thumbnail_info": infoThumbnailInfo,
                ],
            ]
        ])

        let anyTypedEvent = try XCTUnwrap(eventOrNil).typed()
        let typedEvent = try XCTUnwrap(anyTypedEvent as? TypedEvent)

        XCTAssertEqual(typedEvent.roomId, roomId)
        XCTAssertEqual(typedEvent.eventId, eventId)
        XCTAssertEqual(typedEvent.sender, sender)

        XCTAssertEqual(typedEvent.avatarURL, URL(string: urlString)!)

        XCTAssertEqual(typedEvent.avatarInfo?.height, infoHeight)
        XCTAssertEqual(typedEvent.avatarInfo?.width, infoWidth)
        XCTAssertEqual(typedEvent.avatarInfo?.mimeType, infoMimeType)
        XCTAssertEqual(typedEvent.avatarInfo?.size, infoSize)
        XCTAssertEqual(typedEvent.avatarInfo?.thumbnailURL, URL(string: infoThumbnailURL)!)
//        XCTAssertEqual(typedEvent.avatarInfo?.thumbnailFile, infoThumbnailFile)
//        XCTAssertEqual(typedEvent.avatarInfo?.thumbnailInfo, infoThumbnailInfo)
    }
}
