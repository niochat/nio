import XCTest

@testable import NioKit

class RoomStateTests: XCTestCase {
    func testRoomState() throws {
        let events: [Event] = [
            .message(.init(id: 1, age: 1, body: "Holle World!")),
            .edit(.init(id: 2, age: 2, messageId: 1, messageBody: "Hollo World!")),
            .like(.init(id: 3, age: 3, messageId: 0)),
            .message(.init(id: 4, age: 4, body: "Lorem ipsum!")),
            .like(.init(id: 5, age: 5, messageId: 1)),
            .edit(.init(id: 6, age: 6, messageId: 1, messageBody: "Hello World!")),
            .like(.init(id: 7, age: 7, messageId: 1)),
            .redact(.init(id: 8, age: 8, messageId: 4)),
        ]

        var roomState = RoomState()

        for event in events {
            try roomState.add(event: event).get()
        }

        for eventViewModel in roomState.viewModelsByEventId {
            print("model:", eventViewModel)
        }

        for stashedEvent in roomState.stashedEvents {
            print("stashed:", stashedEvent)
        }

        let expected = RoomState(
            viewModelsByEventId: [
                1: .message(.init(id: 1, age: 1, body: "Hello World!", likes: 2)),
                4: .tombstone(.init(id: 4, age: 4)),
            ],
            eventIdsByAge: [
                .init(id: 1, age: 1),
                .init(id: 4, age: 4),
            ],
            stashedEvents: [
                0: [.like(.init(id: 3, age: 3, messageId: 0))],
            ]
        )

        XCTAssertEqual(roomState, expected)
    }

    func testRoomStateLoadHistory() throws {
        let events: [Event] = [
            .message(.init(id: 1, age: 1, body: "Holle World!")),
            .edit(.init(id: 2, age: 2, messageId: 1, messageBody: "Hollo World!")),
            .like(.init(id: 3, age: 3, messageId: 0)),
            .message(.init(id: 4, age: 4, body: "Lorem ipsum!")),
            .like(.init(id: 5, age: 5, messageId: 1)),
            .edit(.init(id: 6, age: 6, messageId: 1, messageBody: "Hello World!")),
            .like(.init(id: 7, age: 7, messageId: 1)),
            .redact(.init(id: 8, age: 8, messageId: 4)),
            .message(.init(id: 0, age: 0, body: "First!")),
        ]

        var roomState = RoomState()

        for event in events {
            try roomState.add(event: event).get()
        }

        for viewModelByEventId in roomState.viewModelsByEventId {
            print("viewModelByEventId:", viewModelByEventId)
        }

        for eventIdByAge in roomState.eventIdsByAge {
            print("eventIdByAge:", eventIdByAge)
        }

        for stashedEvent in roomState.stashedEvents {
            print("stashedEvent:", stashedEvent)
        }

        let expected = RoomState(
            viewModelsByEventId: [
                0: .message(.init(id: 0, age: 0, body: "First!", likes: 1)),
                1: .message(.init(id: 1, age: 1, body: "Hello World!", likes: 2)),
                4: .tombstone(.init(id: 4, age: 4)),
            ],
            eventIdsByAge: [
                .init(id: 0, age: 0),
                .init(id: 1, age: 1),
                .init(id: 4, age: 4),
            ],
            stashedEvents: [
                :
            ]
        )

        XCTAssertEqual(roomState, expected)
    }

//    func testPerformanceExample() throws {
//        // This is an example of a performance test case.
//        self.measure {
//            // Put the code you want to measure the time of here.
//        }
//    }
}
