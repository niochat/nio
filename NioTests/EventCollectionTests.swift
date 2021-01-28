import XCTest
import SwiftMatrixSDK

@testable import Nio
@testable import NioKit

// swiftlint:disable identifier_name

class EventCollectionTests: XCTestCase {
    func testReadConnectedEdges() {
        let m = kMXEventTypeStringRoomMessage

        let m1 = MockEvent(sender: "A", type: m, timestamp: 0, isRedacted: false)
        let m2 = MockEvent(sender: "A", type: m, timestamp: 0, isRedacted: false)
        let m3 = MockEvent(sender: "A", type: m, timestamp: 0, isRedacted: false)

        let events = [m1, m2, m3]

        XCTAssertEqual(EventCollection(events).connectedEdges(of: m1), [.bottomEdge])
        XCTAssertEqual(EventCollection(events).connectedEdges(of: m2), [.topEdge, .bottomEdge])
        XCTAssertEqual(EventCollection(events).connectedEdges(of: m3), [.topEdge])

        // FIXME: This obviously needs to cover all cases.
    }
}
