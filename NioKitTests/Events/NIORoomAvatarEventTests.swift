import XCTest

import SwiftMatrixSDK

@testable import NioKit

class NIORoomAvatarEventTests: XCTestCase {
    func testTyped() throws {
        typealias TypedEvent = NIORoomAvatarEvent

        let eventId = "$123456789012PhrSn:example.org"
        let sender = "@example:example.org"

        let roomId = "abcdef"

        let urlString = "https://example.org/avatar.png"

        let infoHeight = 123
        let infoWidth = 456
        let infoMimeType = ""
        let infoSize = 1234
        let infoThumbnailURL = urlString
//        let infoThumbnailFile = ""
//        let infoThumbnailInfo = ""

        let eventOrNil = MXEvent(fromJSON: [
            "event_id": eventId,
            "sender": sender,
            "type": "m.room.avatar",
            "state_key": "",
            "room_id": roomId,
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

        XCTAssertEqual(typedEvent.id, eventId)
        XCTAssertEqual(typedEvent.sender, sender)

        XCTAssertEqual(typedEvent.roomId, roomId)

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
