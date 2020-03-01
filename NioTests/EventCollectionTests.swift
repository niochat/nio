import XCTest
import SwiftMatrixSDK
@testable import Nio

//swiftlint:disable identifier_name

class EventCollectionTests: XCTestCase {
    var A1 = MockEvent(sender: "A", eventId: "A1")
    var A2 = MockEvent(sender: "A", eventId: "A2")
    var A3 = MockEvent(sender: "A", eventId: "A3")
    var B1 = MockEvent(sender: "B", eventId: "B1")

    func testReadGroupPosition() {
        XCTAssertEqual(EventCollection([A1]).connectedEdges(of: A1), [.bottomEdge])
        XCTAssertEqual(EventCollection([A1, A2, B1]).connectedEdges(of: A2), [.topEdge])
        XCTAssertEqual(EventCollection([A1, A2, B1]).connectedEdges(of: B1), [.bottomEdge])
        XCTAssertEqual(EventCollection([A1, A2, A3]).connectedEdges(of: A2), [.topEdge, .bottomEdge])
    }
}

class MockEvent: MXEvent {
    init(sender: String, eventId: String) {
        super.init()
        self.sender = sender
        self.eventId = eventId
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
