import Foundation
import Combine
import SwiftMatrixSDK

class NIORecentRooms: ObservableObject {
    var objectWillChange = ObservableObjectPublisher()

    var listenReference: Any?

    func startListening() {
        // roomState is nil for presence events, just for future reference
        listenReference = MatrixServices.shared.session?.listenToEvents { event, direction, roomState in
            let affectedRooms = self.rooms.filter { $0.summary.roomId == event.roomId }
            for room in affectedRooms {
                room.add(event: event, direction: direction, roomState: roomState as? MXRoomState)
            }
            self.objectWillChange.send()
        }
    }

    deinit {
        MatrixServices.shared.session?.removeListener(self.listenReference)
    }

    var rooms: [NIORoom] {
        MatrixServices.shared.session?
            .rooms
            .sorted { $0.summary.lastMessageDate > $1.summary.lastMessageDate }
            .map { NIORoom($0) } ?? []
    }
}
