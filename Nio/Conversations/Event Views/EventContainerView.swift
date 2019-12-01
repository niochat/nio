import SwiftUI
import SwiftMatrixSDK

struct EventContainerView: View {
    @EnvironmentObject var store: MatrixStore<AppState, AppAction>

    var event: MXEvent
    var position: GroupPosition
    var isDirect: Bool

    var body: some View {
        switch MXEventType(identifier: event.type) {
        case .roomMessage:
            let message = (event.content["body"] as? String) ?? ""
            return AnyView(
                MessageView(text: message,
                            sender: event.sender,
                            showSender: !isDirect && position.showMessageSender,
                            timestamp: Formatter.string(for: event.timestamp, timeStyle: .short),
                            isMe: MatrixServices.shared.credentials?.userId == event.sender)
                    .padding(.top, position.topMessagePadding)
            )
        case .roomMember:
            let displayname = (event.content["displayname"] as? String) ?? ""
            let membership = (event.content["membership"] as? String) ?? ""
            return AnyView(
                GenericEventView(text: "\(displayname) \(membership)'d") // 🤷
                    .padding(.top, position.topMessagePadding)
            )
        default:
            return AnyView(
                GenericEventView(text: "\(event.type!): \(event.content!)")
                    .padding(.top, position.topMessagePadding)
            )
        }
    }
}
