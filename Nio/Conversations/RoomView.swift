import SwiftUI
import Combine
import KeyboardObserving
import SwiftMatrixSDK

struct RoomContainerView: View {
    @ObservedObject var room: NIORoom

    @State var showAttachmentPicker = false

    var body: some View {
        RoomView(
            events: room.events(),
            isDirect: room.isDirect,
            showAttachmentPicker: $showAttachmentPicker,
            onCommit: { message in
                self.room.send(text: message)
            }
        )
        .navigationBarTitle(Text(room.summary.displayname ?? ""), displayMode: .inline)
        .keyboardObserving()
        .actionSheet(isPresented: $showAttachmentPicker) {
            self.attachmentPickerSheet
        }
        .onAppear { self.room.markAllAsRead() }
    }

    var attachmentPickerSheet: ActionSheet {
        ActionSheet(title: Text("Not yet implemented"))
    }
}

struct RoomView: View {
    var events: EventCollection
    var isDirect: Bool

    @Binding var showAttachmentPicker: Bool
    var onCommit: (String) -> Void

    @State private var message = ""

    var body: some View {
        VStack {
            ReverseList(events.wrapped) { event in
                EventContainerView(event: event,
                                   connectedEdges: self.events.connectedEdges(of: event),
                                   showSender: !self.isDirect)
                    .padding(.horizontal)
            }

            MessageComposerView(message: $message,
                                showAttachmentPicker: $showAttachmentPicker,
                                onCommit: send)
                .padding(.horizontal)
                .padding(.bottom, 10)
        }
    }

    private func send() {
        onCommit(message)
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
