import SwiftUI

struct MessageView: View {
    @Environment(\.colorScheme) var colorScheme

    var text: String
    var sender: String
    var showSender = false
    var timestamp: String
    var isMe: Bool

    var textIsShortEmoji: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).containsOnlyEmoji
            && text.count <= 3
    }

    var textColor: Color {
        if isMe {
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
        if isMe {
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
            if isMe {
                Spacer()
            }
            VStack(alignment: .leading) {
                if showSender && !isMe {
                    Text(sender)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                if textIsShortEmoji {
                    Text(text)
                        .font(.system(size: 60))
                } else {
                    ZStack(alignment: .bottomTrailing) {
                        (
                            Text(text).foregroundColor(textColor)
                            +
                            // This is a spacing placeholder for the actual timestamp below.
                            Text(" \(timestamp)")
                                .font(.caption)
                                .foregroundColor(.clear)
                        )

                        Text(timestamp)
                            .font(.caption)
                            .foregroundColor(isMe ? .white : .gray)
                            .offset(x: 0, y: -1)
                            .accessibility(hidden: true)
                    }
                    .padding(10)
                    .background(backgroundColor)
                    .cornerRadius(15)
                    .padding(.top, -8)
                }
            }
            if !isMe {
                Spacer()
            }
        }
    }
}

struct MessageView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            MessageView(text: "This is a longer demo message that needs line breaks to be displayed in its entirety.",
                        sender: "Morpheus",
                        showSender: true,
                        timestamp: "12:29",
                        isMe: false)
            MessageView(text: "Demo message",
                        sender: "Morpheus",
                        showSender: false,
                        timestamp: "12:29",
                        isMe: false)
            MessageView(text: "Ping",
                        sender: "",
                        showSender: false,
                        timestamp: "12:29",
                        isMe: true)
            MessageView(text: "Ping 2",
                        sender: "",
                        showSender: false,
                        timestamp: "12:29",
                        isMe: true)
            MessageView(text: "🐧",
                        sender: "",
                        showSender: false,
                        timestamp: "12:29",
                        isMe: true)
            MessageView(text: "🕴",
                        sender: "Agent Smith",
                        showSender: true,
                        timestamp: "12:29",
                        isMe: false)
        }
        .padding()
        .accentColor(.purple)
        .previewLayout(.sizeThatFits)
//        .environment(\.colorScheme, .dark)
//        .environment(\.sizeCategory, .extraExtraLarge)
    }
}
