import Foundation

struct RoomSummary: Identifiable {
    var id: String {
        roomId
    }

    var roomId: String

    var displayName: String
    var avatarURL: URL?

    var lastMessageTimestamp: UInt64 // TODO: This should be Date, just like with MXEvent
    var lastMessage: Event?
}
