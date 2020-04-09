import SwiftUI

struct TypingIndicatorView: View {
    @EnvironmentObject private var room: NIORoom
    @Environment(\.userId) var userId

    var text: String {
        let users = (room.room.typingUsers?.filter { $0 != userId } ?? [])
        var joinedUsers = ""
        if users.count <= 3 {
            joinedUsers = users.joined(separator: ", ")
        } else {
            joinedUsers = "Several people"
        }
        let isAre = users.count == 1 ? "is" : "are"
        return "\(joinedUsers) \(isAre) typing..."
    }

    var body: some View {
        HStack {
            Text(text)
                .font(.caption)
                .foregroundColor(.gray)
            Spacer()
        }
        .padding(.horizontal)
    }
}
