import SwiftUI
import MatrixSDK

import NioKit

struct EventContainerView: View {
    let event: MXEvent
    let reactions: [Reaction]
    let connectedEdges: ConnectedEdges
    let showSender: Bool
    let edits: [MXEvent]
    let contextMenuModel: EventContextMenuModel

    var body: some View {
        // NOTE: For as long as https://github.com/matrix-org/matrix-ios-sdk/pull/843
        // remains unresolved keep in mind that
        // `.keyVerificationStart`, `.keyVerificationAccept`, `.keyVerificationKey`,
        // `.keyVerificationMac`, `.keyVerificationCancel` & `.reaction`
        // may get wrongly recognized as `.custom(…)`, instead.
        // FIXME: Remove comment when linked bug fix has been merged.
        switch MXEventType(identifier: event.type) {
        case .roomMessage:
            RoomMessageView(event: event, reactions: reactions,
                            connectedEdges: connectedEdges,
                            showSender: showSender, edits: edits,
                            contextMenuModel: contextMenuModel)
        case .roomMember:
            RoomMemberEventView(model: .init(event: event))

        case .roomTopic:
            RoomTopicEventView(model: .init(event: event))

        case .roomPowerLevels:
            RoomPowerLevelsEventView(model: .init(event: event))

        case .roomName:
            RoomNameEventView(model: .init(event: event))

        default:
            GenericEventView(text: "\(event.type!)\n\(event.content!)")
                .padding(.top, 10)
        }
    }

    private struct RoomMessageView: View {

        fileprivate let event: MXEvent
        fileprivate let reactions: [Reaction]
        fileprivate let connectedEdges: ConnectedEdges
        fileprivate let showSender: Bool
        fileprivate let edits: [MXEvent]
        fileprivate let contextMenuModel: EventContextMenuModel

        private var topPadding: CGFloat {
            connectedEdges.contains(.topEdge) ? 2.0 : 8.0
        }

        private var bottomPadding: CGFloat {
            connectedEdges.contains(.bottomEdge) ? 2.0 : 8.0
        }

        private enum Model {
            case model(MessageViewModel)
            case invalidEventType(MXEventType)
            case otherError(Swift.Error)
        }

        private var model: Model {
            var newEvent = event
            if event.contentHasBeenEdited() {
                newEvent = edits.last ?? event
            }

            do {
                return .model(try MessageViewModel(
                    event: newEvent,
                    reactions: reactions,
                    showSender: showSender
                ))
            } catch let error as MessageViewModel.Error {
                switch error {
                case .invalidEventType(let eventType):
                    return .invalidEventType(eventType)
                }
            } catch let error {
                return .otherError(error)
            }
        }

        var body: some View {
            if event.isRedactedEvent() {
                let redactor = event.redactedBecause["sender"] as? String ?? L10n.Event.unknownSenderFallback
                let reason = (event.redactedBecause["content"] as? [AnyHashable: Any])?["body"] as? String
                RedactionEventView(model: .init(sender: event.sender, redactor: redactor, reason: reason))
            } else if event.isEdit() {
                EmptyView()
            } else if event.isMediaAttachment() {
                MediaEventView(model: .init(event: event, showSender: showSender),
                               contextMenuModel: contextMenuModel)
                    .padding(.top, topPadding)
                    .padding(.bottom, bottomPadding)
            } else {
                switch model {
                case .model(let messageModel):
                    MessageView(
                        model: .constant(messageModel),
                        contextMenuModel: contextMenuModel,
                        connectedEdges: connectedEdges,
                        isEdited: event.contentHasBeenEdited()
                    )
                    .padding(.top, topPadding)
                    .padding(.bottom, bottomPadding)

                case .invalidEventType(let eventType):
                    Text("⚠️ Invalid event type \(String(describing: eventType))")
                case .otherError(let error):
                    Text("⚠️ Unknown error \(String(describing: error))")
                }
            }
        }
    }
}
