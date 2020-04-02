import SwiftUI
import SwiftMatrixSDK

struct EventContainerView: View {
    var event: MXEvent
    var connectedEdges: ConnectedEdges
    var isDirect: Bool

    private var topPadding: CGFloat {
        connectedEdges.contains(.topEdge) ? 2.0 : 8.0
    }

    private var bottomPadding: CGFloat {
        connectedEdges.contains(.bottomEdge) ? 2.0 : 8.0
    }

    var body: some View {
        switch MXEventType(identifier: event.type) {
        case .roomMessage:
            // FIXME: remove
            // swiftlint:disable:next force_try
            let messageModel = try! MessageViewModel(event: event)
            return AnyView(
                MessageView(
                    model: .constant(messageModel),
                    connectedEdges: connectedEdges
                )
                .padding(.top, topPadding)
                .padding(.bottom, bottomPadding)
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
