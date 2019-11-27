import Foundation
import Combine
import SwiftMatrixSDK

class NIORecentRooms: ObservableObject {
    var objectWillChange = ObservableObjectPublisher()

    var listenReference: Any?

    func startListening() {
        listenReference = MatrixServices.shared.session?.listenToEvents { _, _, _ in
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
