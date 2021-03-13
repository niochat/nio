import SwiftUI

import NioKit

struct TypingIndicatorContainerView: View {
    @EnvironmentObject private var room: NIORoom
    @Environment(\.userId) private var userId

    private var typingUsers: [String] {
        room.room.typingUsers?.filter { $0 != userId} ?? []
    }

    var body: some View {
        TypingIndicatorView(typingUsers: typingUsers)
    }
}

struct TypingIndicatorView: View {
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    let typingUsers: [String]

    private var text: String {
        switch typingUsers.count {
        case 1:
            return L10n.TypingIndicator.single(typingUsers.first!)
        case 2:
            return L10n.TypingIndicator.two(typingUsers[0], typingUsers[1])
        default:
            return L10n.TypingIndicator.many
        }
    }

    private var backgroundColor: Color {
        switch self.colorScheme {
        case .dark:
            return Color(#colorLiteral(red: 0.1221848231, green: 0.1316168257, blue: 0.1457917546, alpha: 1))
        default:
            return Color(#colorLiteral(red: 0.968541801, green: 0.9726034999, blue: 0.9763545394, alpha: 1))
        }
    }

    var body: some View {
        HStack {
            Group {
                SFSymbol.typing
                Text(text)
            }
            .font(.caption)
            .foregroundColor(.gray)
            Spacer()
        }
        .padding(8)
        .background(self.backgroundColor)
    }
}

struct TypingIndicatorView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            TypingIndicatorView(typingUsers: ["Jane Doe"])
            TypingIndicatorView(typingUsers: ["Jane Doe", "John Doe"])
            TypingIndicatorView(typingUsers: ["Jane Doe", "John Doe", "Jill Doe"])

            TypingIndicatorView(typingUsers: ["Jane Doe", "John Doe"])
            .environment(\.colorScheme, .dark)

            TypingIndicatorView(typingUsers: ["Jane Doe", "John Doe"])
            .environment(\.sizeCategory, .accessibilityLarge)
        }
        .previewLayout(.sizeThatFits)
    }
}
