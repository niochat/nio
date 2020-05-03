import Foundation
import Combine
import SwiftMatrixSDK

// Implementation heavily inspired by [Messagerie](https://github.com/manuroe/messagerie).

class RoomSummariesSource: MXRoomSummaryUpdater {
    private let subject = PassthroughSubject<[RoomSummary], Never>()
    var publisher: AnyPublisher<[RoomSummary], Never> {
        subject.eraseToAnyPublisher()
    }

    private let session: Session
    private let mxSession: MXSession

    private let eventFactory: EventFactory

    private lazy var processingQueue: DispatchQueue = {
        DispatchQueue(label: "chat.nio.RoomSummariesSource")
    }()

    init(session: Session) {
        self.session = session
        self.mxSession = session.session
        self.eventFactory = EventFactory(session: session)

        super.init()
        self.mxSession.roomSummaryUpdateDelegate = self
    }

    func update() {
        let roomSummaries = self.mxSession.roomsSummaries()

        processingQueue.async {
            let rooms = roomSummaries?
                .filter { !$0.hiddenFromUser }
                .compactMap {
                    RoomSummary(roomId: $0.roomId,
                                displayName: $0.displayname ?? $0.roomId,
                                avatarURL: self.session.mediaURL(for: $0.avatar),
                                lastMessageTimestamp: $0.lastMessageOriginServerTs ,
                                lastMessage: $0.nio_lastEvent)
                }

            DispatchQueue.main.async {
                rooms.map { self.subject.send($0) }
            }
        }
    }
}

// MARK: MXRoomSummaryUpdater

extension RoomSummariesSource {
    override func session(_ session: MXSession!,
                          update summary: MXRoomSummary!,
                          withLast event: MXEvent!,
                          eventState: MXRoomState!,
                          roomState: MXRoomState!) -> Bool {
        let result = super.session(session,
                                   update: summary,
                                   withLast: event,
                                   eventState: eventState,
                                   roomState: roomState)
        if result {
            if let lastEvent = eventFactory.event(from: event,
                                                  direction: .forwards,
                                                  roomState: roomState) {
                summary.nio_lastEvent = lastEvent
                self.update()
            }
        }
        return result
    }
}
