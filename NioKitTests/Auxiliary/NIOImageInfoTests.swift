import XCTest

import SwiftMatrixSDK

@testable import NioKit

class NIOImageInfoTests: XCTestCase {
    func testTyped() throws {
        typealias TypedEvent = NIORoomNameEvent

        let height: Int = 123
        let width: Int = 456
        let mimeType: String = ""
        let size: Int = 1234
        let thumbnailURL: String = "https://example.org/avatar.png"
//        let thumbnailFile: [String: Any] = [:]
//        let thumbnailInfo: [String: Any] = [:]

        let imageInfo = try NIOImageInfo(fromJSON: [
            "h": "\(height)",
            "w": "\(width)",
            "mimetype": mimeType,
            "size": "\(size)",
            "thumbnail_url": thumbnailURL,
//            "thumbnail_file": thumbnailFile,
//            "thumbnail_info": thumbnailInfo,
        ])

        XCTAssertEqual(imageInfo.height, height)
        XCTAssertEqual(imageInfo.width, width)
        XCTAssertEqual(imageInfo.mimeType, mimeType)
        XCTAssertEqual(imageInfo.size, size)
        XCTAssertEqual(imageInfo.thumbnailURL, URL(string: thumbnailURL)!)
//        XCTAssertEqual(imageInfo.thumbnailFile?.isEmpty)
//        XCTAssertEqual(imageInfo.thumbnailInfo?.isEmpty)
    }
}
