import SwiftUI

struct MessageView: View {
    @Environment(\.colorScheme) var colorScheme

    var message: StubMessage

    var textColor: Color {
        if message.isMe {
            return .white
        }
        switch colorScheme {
        case .light:
            return .black
        case .dark:
            return .white
        @unknown default:
            return .black
        }
    }

    var backgroundColor: Color {
        if message.isMe {
            return .accentColor
        }
        switch colorScheme {
        case .light:
            return Color(#colorLiteral(red: 0.8979603648, green: 0.8980901837, blue: 0.9175375104, alpha: 1))
        case .dark:
            return Color(#colorLiteral(red: 0.1450805068, green: 0.1490308046, blue: 0.164680928, alpha: 1))
        @unknown default:
            return Color(#colorLiteral(red: 0.8979603648, green: 0.8980901837, blue: 0.9175375104, alpha: 1))
        }
    }

    var body: some View {
        HStack {
            if message.isMe {
                Spacer()
            }
            VStack(alignment: .leading) {
//                if !message.isMe {
//                    Text(message.sender)
//                        .font(.caption)
//                        .foregroundColor(.gray)
//                        .padding(.bottom, 5)
//                }
                if message.message.containsOnlyEmoji && message.message.count <= 3 {
                    Text(message.message)
                        .font(.system(size: 60))
                        .padding(10)
                } else {
                    Text(message.message)
                        .foregroundColor(textColor)
                        .padding(10)
                        .background(backgroundColor)
                        .cornerRadius(15)
                }
            }
        }
    }
}
