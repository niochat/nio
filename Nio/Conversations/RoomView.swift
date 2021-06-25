import Combine
import MatrixSDK
import SwiftUI

import Intents
import CoreSpotlight
import CoreServices

import NioKit

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
    @State private var canScrollFurther = true

    private var areOtherUsersTyping: Bool {
        !(room.room.typingUsers?.filter { $0 != userId }.isEmpty ?? true)
    }

    var body: some View {
        VStack {
            ReverseList(events.renderableEvents, hasReachedTop: $shouldPaginate, canScrollFurther: $canScrollFurther) { event in
                EventContainerView(event: event,
                                   reactions: self.events.reactions(for: event),
                                   connectedEdges: self.events.connectedEdges(of: event),
                                   showSender: !self.isDirect,
                                   edits: self.events.relatedEvents(of: event).filter { $0.isEdit() },
                                   contextMenuModel: EventContextMenuModel(
                                       event: event,
                                       userId: self.userId,
                                       onReact: { self.onReact(event.eventId) },
                                       onReply: {},
                                       onEdit: { self.edit(event: event) },
                                       onRedact: {
                                           if event.sentState == MXEventSentStateFailed {
                                               room.removeOutgoingMessage(event)
                                           } else {
                                               self.eventToRedact = event.eventId
                                           }
                                       }
                                   ))
                    .padding(.horizontal)
            }

            if #available(macOS 11, *) {
                Divider()
            }

            if areOtherUsersTyping {
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
                asyncDetached {
                    await paginate(topEvent: topEvent)
                }
            }
        }
        .onAppear {
            asyncDetached {
                await room.createPagination()
            }
        }
        .alert(item: $eventToRedact) { eventId in
            Alert(title: Text(verbatim: L10n.Room.Remove.title),
                  message: Text(verbatim: L10n.Room.Remove.message),
                  primaryButton: .destructive(Text(verbatim: L10n.Room.Remove.action), action: { self.onRedact(eventId, nil) }),
                  secondaryButton: .cancel())
        }
        .userActivity("chat.nio.chat") { userActivity in
            userActivity.isEligibleForHandoff = true
            userActivity.isEligibleForSearch = true
            userActivity.isEligibleForPrediction = true
            userActivity.title = room.displayName
            userActivity.userInfo = ["id": room.id.rawValue as String]
            
            let attributes = CSSearchableItemAttributeSet(itemContentType: kUTTypeItem as String)
            
            attributes.contentDescription = "Open chat with \(room.displayName)"
            attributes.instantMessageAddresses = [ room.room.roomId ]
            userActivity.contentAttributeSet = attributes
            userActivity.webpageURL = URL(string: "https://matrix.to/#/\(room.room.roomId ?? "")")
            
            // TODO: implement with a viewDelegate to save the current text into the handsof
            // userActivity.needsSave = true
            
            print("advertising: \(room.displayName) \(String(describing: userActivity.webpageURL))")
        }
    }

    private nonisolated func paginate(topEvent: MXEvent) async {
        print("paginating")
        let canScroll = await room.paginate(topEvent)
        await self.setCanScroll(to: canScroll)
    }
    
    private func setCanScroll(to canScroll: Bool) {
        self.canScrollFurther = canScroll
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
