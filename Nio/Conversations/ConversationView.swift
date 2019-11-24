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
        ConversationView(
            events: conversation.enumeratorForStoredMessagesWithType(in: Self.displayedMessageTypes)?.nextEventsBatch(50) ?? [],
            isDirect: conversation.isDirect
        )
        .navigationBarTitle(Text(conversation.summary.displayname ?? ""), displayMode: .inline)
        .keyboardObserving()
    }
}

struct ConversationView: View {
    var events: [MXEvent]
    var isDirect: Bool

    @State private var message = ""

    var body: some View {
        VStack {
            ScrollView {
                ForEach(events.reversed()) { event in
                    EventContainerView(event: event, isDirect: self.isDirect)
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                }
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
