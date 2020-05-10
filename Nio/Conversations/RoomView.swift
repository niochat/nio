import SwiftUI
import Combine
import KeyboardObserving
import SwiftMatrixSDK

struct RoomContainerView: View {
    @ObservedObject var room: NIORoom

    @State var showAttachmentPicker = false
    @State var showImagePicker = false
    @State var eventToReactTo: String?

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
        .keyboardObserving()
        .actionSheet(isPresented: $showAttachmentPicker) {
            self.attachmentPickerSheet
        }
        .sheet(item: $eventToReactTo) { eventId in
            ReactionPicker { reaction in
                self.room.react(toEventId: eventId, emoji: reaction)
                self.eventToReactTo = nil
            }
        }
        .onAppear { self.room.markAllAsRead() }
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
    @Environment(\.userId) var userId
    @EnvironmentObject var room: NIORoom

    var events: EventCollection
    var isDirect: Bool

    @Binding var showAttachmentPicker: Bool
    var onCommit: (String) -> Void

    var onReact: (String) -> Void
    var onRedact: (String, String?) -> Void
    var onEdit: (String, String) -> Void

    @State private var editEventId: String?
    @State private var eventToRedact: String?

    @State private var message = ""
    @State private var highlightMessage: String?
    @State private var isEditingMessage: Bool = false

    var body: some View {
        VStack {
            ReverseList(events.renderableEvents) { event in
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
                                    onRedact: { self.eventToRedact = event.eventId }))
                    .padding(.horizontal)
            }
            if !(room.room.typingUsers?.filter { $0 != userId }.isEmpty ?? false) {
                TypingIndicatorContainerView()
            }
            MessageComposerView(
                message: $message,
                showAttachmentPicker: $showAttachmentPicker,
                isEditing: $isEditingMessage,
                highlightMessage: highlightMessage,
                onCancel: cancelEdit,
                onCommit: send
            )
                .padding(.horizontal)
                .padding(.bottom, 10)
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
            onCommit(message)
            message = ""
        } else {
            onEdit(message, editEventId!)
            message = ""
            editEventId = nil
            highlightMessage = nil
        }
    }

    private func edit(event: MXEvent) {
        message = event.content["body"] as? String ?? ""
        highlightMessage = message
        editEventId = event.eventId
    }

    private func cancelEdit() {
        editEventId = nil
        highlightMessage = nil
        message = ""
    }
}

//struct ConversationView_Previews: PreviewProvider {
//    static var previews: some View {
//        NavigationView {
//            ConversationView()
//                .accentColor(.purple)
//                .navigationBarTitle("Morpheus", displayMode: .inline)
//        }
//    }
//}
