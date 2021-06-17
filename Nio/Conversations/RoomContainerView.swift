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

    private var roomView: RoomView {
      RoomView(
          events: room.events(),
          isDirect: room.isDirect,
          showAttachmentPicker: $showAttachmentPicker,
          onCommit: { message in
          asyncDetached {
              await self.room.send(text: message)
          }
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
    }

    var body: some View {
        roomView
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
                title: Text(verbatim: L10n.Room.Invitation.JoinAlert.title),
                message: Text(verbatim: L10n.Room.Invitation.JoinAlert.message(roomName)),
                primaryButton: .default(
                    Text(verbatim: L10n.Room.Invitation.JoinAlert.joinButton),
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
                    asyncDetached {
                        await self.room.sendImage(image: image)
                    }
                }
            }
        )
    }

    private var attachmentPickerSheet: ActionSheet {
        ActionSheet(
            title: Text(verbatim: L10n.Room.Attachment.selectType), buttons: [
                .default(Text(verbatim: L10n.Room.Attachment.typePhoto), action: {
                    self.showImagePicker = true
                }),
                .cancel()
            ]
        )
    }
}

