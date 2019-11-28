import Foundation
import Combine
import SwiftMatrixSDK

class NIORoom: ObservableObject {
    static var displayedMessageTypes = [
        kMXEventTypeStringRoomMessage,
        kMXEventTypeStringRoomMember,
        kMXEventTypeStringRoomTopic
    ]

    private var room: MXRoom

    @Published var summary: NIORoomSummary

    var objectWillChange = ObservableObjectPublisher()

    init(_ room: MXRoom) {
        self.room = room
        self.summary = NIORoomSummary(room.summary)

        let enumerator = room.enumeratorForStoredMessages//WithType(in: Self.displayedMessageTypes)
        let currentBatch = enumerator?.nextEventsBatch(200) ?? []
        print("Got \(currentBatch.count) events.")

        let filteredEvents = currentBatch.filter { Self.displayedMessageTypes.contains($0.type) }
        self.eventCache.append(contentsOf: filteredEvents)
    }

    func add(event: MXEvent, direction: MXTimelineDirection, roomState: MXRoomState?) {
        print("New event of type: \(event.type!)")
        guard Self.displayedMessageTypes.contains(event.type ?? "") else { return }

        switch direction {
        case .backwards:
            self.eventCache.insert(event, at: 0)
        case .forwards:
            self.eventCache.append(event)
        }

        self.objectWillChange.send()
    }

    private var eventCache: [MXEvent] = []

    func events() -> EventCollection {
        return EventCollection(eventCache)
    }

    var isDirect: Bool {
        room.isDirect
    }

    var lastMessage: String {
        let lastMessageEvent = eventCache.last {
            $0.type == kMXEventTypeStringRoomMessage
        }

        return lastMessageEvent?.content["body"] as? String ?? ""
    }

    // MARK: Sending Events

    func send(text: String) {
        guard !text.isEmpty else { return }
        //swiftlint:disable:next redundant_optional_initialization
        var localEcho: MXEvent? = nil
        room.sendTextMessage(text, localEcho: &localEcho) { response in
            print(response)
            self.objectWillChange.send()
        }
        self.objectWillChange.send()
    }

    func markAllAsRead() {
        room.markAllAsRead()
    }
}

extension NIORoom: Identifiable {
    var id: ObjectIdentifier {
        room.id
    }
}
