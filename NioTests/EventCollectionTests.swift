import XCTest
import SwiftMatrixSDK
@testable import Nio

//swiftlint:disable identifier_name

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

class MockEvent: MXEvent {
    init(sender: String, type: String, timestamp: UInt64, isRedacted: Bool) {
        self._type = type
        self.isRedacted = isRedacted
        super.init()
        self.sender = sender
        self.originServerTs = 1000 * timestamp
    }

    var _type: String
    override var type: String! {
        _type
    }

    var isRedacted: Bool
    override func isRedactedEvent() -> Bool {
        isRedacted
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
