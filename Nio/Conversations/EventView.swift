import SwiftUI
import SwiftMatrixSDK

struct EventContainerView: View {
    @EnvironmentObject var store: MatrixStore<AppState, AppAction>

    var event: MXEvent
    var isDirect: Bool

    var body: some View {
        switch MXEventType(identifier: event.type) {
        case .roomMessage:
            let message = (event.content["body"] as? String) ?? ""
            return AnyView(
                MessageView(text: message,
                            sender: event.sender,
                            showSender: !isDirect,
                            isMe: MatrixServices.shared.credentials?.userId == event.sender)
            )
        case .roomMember:
            let displayname = (event.content["displayname"] as? String) ?? ""
            let membership = (event.content["membership"] as? String) ?? ""
            return AnyView(
                GenericEventView(text: "\(displayname) \(membership)'d") // 🤷
            )
        default:
            return AnyView(
                GenericEventView(text: "\(event.type!): \(event.content!)")
            )
        }
    }
}

struct MessageView: View {
    @Environment(\.colorScheme) var colorScheme

    var text: String
    var sender: String
    var showSender = false
    var isMe: Bool

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
                        .padding(.bottom, 5)
                }
                if text.trimmingCharacters(in: .whitespacesAndNewlines).containsOnlyEmoji && text.count <= 3 {
                    Text(text)
                        .font(.system(size: 60))
                        .padding(10)
                } else {
                    Text(text)
                        .foregroundColor(textColor)
                        .padding(10)
                        .background(backgroundColor)
                        .cornerRadius(15)
                }
            }
            if !isMe {
                Spacer()
            }
        }
    }
}

struct GenericEventView: View {
    var text: String

    var body: some View {
        HStack {
            Spacer()
            Text(text)
                .font(.caption)
                .foregroundColor(.gray)
            Spacer()
        }
    }
}
