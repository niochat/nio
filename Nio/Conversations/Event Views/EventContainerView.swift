import SwiftUI
import SwiftMatrixSDK

struct EventContainerView: View {
    @EnvironmentObject var store: MatrixStore<AppState, AppAction>

    var event: MXEvent
    var connectedEdges: ConnectedEdges
    var isDirect: Bool

    var body: some View {
        switch MXEventType(identifier: event.type) {
        case .roomMessage:
            // FIXME: remove
            // swiftlint:disable:next force_try
            let messageModel = try! MessageViewModel(event: event)
            return AnyView(
                MessageView(
                    model: .constant(messageModel),
                    connectedEdges: []
                )
                    .padding(.top, 10)
            )
        case .roomMember:
            let displayname = (event.content["displayname"] as? String) ?? ""
            let membership = (event.content["membership"] as? String) ?? ""
            return AnyView(
                GenericEventView(text: "\(displayname) \(membership)'d") // 🤷
                    .padding(.top, 10)
            )
        default:
            return AnyView(
                GenericEventView(text: "\(event.type!): \(event.content!)")
                    .padding(.top, 10)
            )
        }
    }
}
