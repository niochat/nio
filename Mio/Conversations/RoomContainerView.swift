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
        VStack(spacing: 0) {
            Divider() // TBD: This might be better done w/ toolbar styling
            roomView
        }
        .navigationTitle(Text(room.summary.displayname ?? ""))
        // TODO: action sheet
        .sheet(item: $eventToReactTo) { eventId in
            ReactionPicker { reaction in
                self.room.react(toEventId: eventId, emoji: reaction)
                self.eventToReactTo = nil
            }
        }
        // TODO: join alert
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
        // TODO: background sheet thing
        .background(Color(.textBackgroundColor))
        .frame(minWidth: Style.minTimelineWidth)
    }

    // TODO: port me to macOS
    /*
    private var attachmentPickerSheet: ActionSheet {
        ActionSheet(
            title: Text(verbatim: L10n.Room.Attachment.selectType), buttons: [
                .default(Text(verbatim: L10n.Room.Attachment.typePhoto), action: {
                    self.showImagePicker = true
                }),
                .cancel()
            ]
        )
    }*/
}


/*struct RecentRoomsContainerView_Previews: PreviewProvider {
    static var previews: some View {
        RecentRoomsView(selectedNavigationItem: .constant(nil), selectedRoomId: .constant(nil), rooms: [])
    }
}*/
