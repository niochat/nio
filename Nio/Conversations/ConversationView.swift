import SwiftUI
import Combine
import KeyboardObserving
import SwiftMatrixSDK

struct ConversationContainerView: View {
    static var displayedMessageTypes = [
        kMXEventTypeStringRoomMessage,
        kMXEventTypeStringRoomMember,
        kMXEventTypeStringRoomTopic
    ]

    @EnvironmentObject var store: MatrixStore<AppState, AppAction>

    var conversation: MXRoom

    var body: some View {
        ConversationView(events: conversation.enumeratorForStoredMessagesWithType(in: Self.displayedMessageTypes)?.nextEventsBatch(50) ?? [])
            .navigationBarTitle(Text(conversation.summary.displayname ?? ""), displayMode: .inline)
            .keyboardObserving()
    }
}

struct ConversationView: View {
    var events: [MXEvent]

    @State private var message = ""

    var body: some View {
        VStack {
            List(messageStore.messages) { message in
                MessageView(message: message)
            }

            MessageComposerView(message: $message,
                                onCommit: send)
                .padding(.horizontal)
                .padding(.bottom, 10)
        }
    }

    private func send() {
//        self.messageStore.append(message: message)
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
