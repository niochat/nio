import SwiftUI
import Combine
import MatrixSDK

import NioKit

struct RoomContainerView: View {
    @ObservedObject var room: NIORoom

    @State private var showAttachmentPicker = false
    @State private var showImagePicker = false
    @State private var eventToReactTo: String?
    @State private var showJoinAlert = false

    var body: some View {
        RoomView(
            events: room.events(),
            isDirect: room.isDirect,
            showAttachmentPicker: $showAttachmentPicker,
            onCommit: { message in
                self.room.send(text: message)
            },
            onReact: { eventId in
                self.eventToReactTo = eventId
            },
            onRedact: { eventId, reason in
                self.room.redact(eventId: eventId, reason: reason)
            },
            onEdit: { message, eventId in
                self.room.edit(text: message, eventId: eventId)
            }
        )
        .navigationBarTitle(Text(room.summary.displayname ?? ""), displayMode: .inline)
        .actionSheet(isPresented: $showAttachmentPicker) {
            self.attachmentPickerSheet
        }
        .sheet(item: $eventToReactTo) { eventId in
            ReactionPicker { reaction in
                self.room.react(toEventId: eventId, emoji: reaction)
                self.eventToReactTo = nil
            }
        }
        .alert(isPresented: $showJoinAlert) {
            let roomName = self.room.summary.displayname ?? self.room.summary.roomId ?? L10n.Room.Invitation.fallbackTitle
            return Alert(
                title: Text(L10n.Room.Invitation.JoinAlert.title),
                message: Text(L10n.Room.Invitation.JoinAlert.message(roomName)),
                primaryButton: .default(
                    Text(L10n.Room.Invitation.JoinAlert.joinButton),
                    action: {
                        self.room.room.mxSession.joinRoom(self.room.room.roomId) { _ in
                            self.room.markAllAsRead()
                        }
                    }),
                secondaryButton: .cancel())
        }
        .onAppear {
            switch self.room.summary.membership {
            case .invite:
                self.showJoinAlert = true
            case .join:
                self.room.markAllAsRead()
            default:
                break
            }
        }
        .environmentObject(room)
        .background(EmptyView()
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(sourceType: .photoLibrary) { image in
                    self.room.sendImage(image: image)
                }
            }
        )
    }

    var attachmentPickerSheet: ActionSheet {
        ActionSheet(
            title: Text(L10n.Room.Attachment.selectType), buttons: [
                .default(Text(L10n.Room.Attachment.typePhoto), action: {
                    self.showImagePicker = true
                }),
                .cancel()
            ]
        )
    }
}

struct RoomView: View {
    @Environment(\.userId) private var userId
    @EnvironmentObject private var room: NIORoom
    @EnvironmentObject private var store: AccountStore

    let events: EventCollection
    let isDirect: Bool

    @Binding var showAttachmentPicker: Bool
    let onCommit: (String) -> Void

    let onReact: (String) -> Void
    let onRedact: (String, String?) -> Void
    let onEdit: (String, String) -> Void

    @State private var editEventId: String?
    @State private var eventToRedact: String?

    @State private var highlightMessage: String?
    @State private var isEditingMessage: Bool = false
    @State private var attributedMessage = NSAttributedString(string: "")

    @State private var shouldPaginate = false

    var body: some View {
        VStack {
            ReverseList(events.renderableEvents, hasReachedTop: $shouldPaginate) { event in
                EventContainerView(event: event,
                                   reactions: self.events.reactions(for: event),
                                   connectedEdges: self.events.connectedEdges(of: event),
                                   showSender: !self.isDirect,
                                   edits: self.events.relatedEvents(of: event).filter { $0.isEdit() },
                                   contextMenuModel: EventContextMenuModel(
                                    event: event,
                                    userId: self.userId,
                                    onReact: { self.onReact(event.eventId) },
                                    onReply: { },
                                    onEdit: { self.edit(event: event) },
                                    onRedact: {
                                        if event.sentState == MXEventSentStateFailed {
                                            room.removeOutgoingMessage(event)
                                        } else {
                                            self.eventToRedact = event.eventId
                                        }
                                    }))
                    .padding(.horizontal)
            }
            if !(room.room.typingUsers?.filter { $0 != userId }.isEmpty ?? false) {
                TypingIndicatorContainerView()
            }
            MessageComposerView(
                showAttachmentPicker: $showAttachmentPicker,
                isEditing: $isEditingMessage,
                attributedMessage: $attributedMessage,
                highlightMessage: highlightMessage,
                onCancel: cancelEdit,
                onCommit: send
            )
                .padding(.horizontal)
                .padding(.bottom, 10)
        }
        .onChange(of: shouldPaginate) { newValue in
            if newValue, let topEvent = events.renderableEvents.first {
                store.paginate(room: self.room, event: topEvent)
            }
        }
        .alert(item: $eventToRedact) { eventId in
            Alert(title: Text(L10n.Room.Remove.title),
                  message: Text(L10n.Room.Remove.message),
                  primaryButton: .destructive(Text(L10n.Room.Remove.action), action: { self.onRedact(eventId, nil) }),
                  secondaryButton: .cancel())
        }
    }

    private func send() {
        if editEventId == nil {
            onCommit(attributedMessage.string)
            attributedMessage = NSAttributedString(string: "")
        } else {
            onEdit(attributedMessage.string, editEventId!)
            attributedMessage = NSAttributedString(string: "")
            editEventId = nil
            highlightMessage = nil
        }
    }

    private func edit(event: MXEvent) {
        attributedMessage = NSAttributedString(string: event.content["body"] as? String ?? "")
        highlightMessage = attributedMessage.string
        editEventId = event.eventId
    }

    private func cancelEdit() {
        editEventId = nil
        highlightMessage = nil
        attributedMessage = NSAttributedString(string: "")
    }
}
