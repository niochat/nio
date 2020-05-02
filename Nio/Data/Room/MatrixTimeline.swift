import Foundation
import Combine

import SwiftMatrixSDK

// Implementation heavily inspired by [Messagerie](https://github.com/manuroe/messagerie).

class MatrixTimeline {
    private let subject = PassthroughSubject<EventUpdate, Never>()
    var publisher: AnyPublisher<EventUpdate, Never> {
        subject.eraseToAnyPublisher()
    }

    private let session: MatrixSession
    private let mxSession: MXSession
    private let roomId: String

    private var timeline: MXEventTimeline?

    private lazy var eventFactory: MatrixEventFactory = {
        MatrixEventFactory(session: self.session)
    }()

    private lazy var processingQueue: DispatchQueue = {
        DispatchQueue(label: "chat.nio.MatrixTimeline.\(self.roomId)")
    }()

    private var remainingMessagesToPaginate: Int?
    var isPaginating: Bool {
        remainingMessagesToPaginate != nil
    }

    init(session: MatrixSession, roomId: String) {
        self.session = session
        self.roomId = roomId
        self.mxSession = session.session
    }

    func paginate(messageCount: UInt, direction: MXTimelineDirection) {
        guard !isPaginating else { return }

        self.getLiveTimeline { timeline in
            guard timeline.canPaginate(direction) else {
                self.remainingMessagesToPaginate = nil
                return
            }

            self.remainingMessagesToPaginate = Int(messageCount)
            timeline.paginate(max(messageCount, 30), direction: direction, onlyFromStore: false) { response in
                let remainingMessagesToPaginate = self.remainingMessagesToPaginate ?? 0
                self.remainingMessagesToPaginate = nil

                switch response {
                case .failure(let error):
                    print(error)
                case .success:
                    if remainingMessagesToPaginate > 0 {
                        self.paginate(messageCount: UInt(remainingMessagesToPaginate), direction: direction)
                    }
                }
            }
        }
    }

    private var dataReady: AnyCancellable?

    func getLiveTimeline(completion: @escaping (_ timeline: MXEventTimeline) -> Void) {
        if let timeline = self.timeline {
            completion(timeline)
            return
        }

        dataReady = session.dataReady.sink { state in
            self.dataReady = nil

            guard let mxRoom = self.mxSession.room(withRoomId: self.roomId) else { return }
            mxRoom.liveTimeline { timeline in
                guard let timeline = timeline else { return }
                timeline.resetPagination()
                self.setupEventListener(for: timeline)
                completion(timeline)
            }
        }
    }

    private func setupEventListener(for timeline: MXEventTimeline) {
        _ = timeline.listenToEvents {
            self.eventHandler(event: $0, direction: $1, roomState: $2)
        }
    }

    private func eventHandler(event: MXEvent, direction: MXTimelineDirection, roomState: MXRoomState) {
        self.processingQueue.async {
            guard let matrixEvent = self.eventFactory.event(from: event, direction: direction, roomState: roomState) else {
                print("failed to create matrix event from \(event)")
                return
            }
            DispatchQueue.main.async {
                switch direction {
                case .forwards:
                    self.subject.send(.forwards(events: [matrixEvent]))
                case .backwards:
                    self.subject.send(.backwards(events: [matrixEvent]))
                }
            }
        }
    }
}
