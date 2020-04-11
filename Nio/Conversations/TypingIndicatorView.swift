import SwiftUI

struct TypingIndicatorView: View {
    @EnvironmentObject private var room: NIORoom
    @Environment(\.userId) var userId

    var text: String {
        let users = (room.room.typingUsers?.filter { $0 != userId } ?? [])
        switch users.count {
        case 1:
            return L10n.TypingIndicator.single(users.first!)
        case 2...3:
            return L10n.TypingIndicator.multiple(users.joined(separator: ", "))
        default:
            return L10n.TypingIndicator.many
        }
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
