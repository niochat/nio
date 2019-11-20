import SwiftUI
import Combine
import KeyboardObserving

struct StubMessage: Identifiable {
    var id: Int
    var sender: String
    var message: String

    var isMe: Bool {
        sender == "Neo"
    }
}

class StubMessageStore: ObservableObject {
    var objectWillChange = ObservableObjectPublisher()

    //swiftlint:disable line_length
    var messages = [
        StubMessage(id: 0, sender: "Morpheus", message: "This line is tapped, so I must be brief. They got to you first, but they’ve underestimated how important you are. If they knew what I know, you’d probably be dead."),
        StubMessage(id: 1, sender: "Neo", message: "What are you talking about. What… what is happening to me?"),
        StubMessage(id: 2, sender: "Morpheus", message: "You are The One, Neo. You see, you may have spent the last few years looking for me, but I’ve spent my entire life looking for you. Now do you still want to meet?"),
        StubMessage(id: 3, sender: "Neo", message: "Yes."),
        StubMessage(id: 4, sender: "Morpheus", message: "Then go to the Adams street Bridge."),
        StubMessage(id: 5, sender: "Neo", message: "🏃‍♀️💨")
    ]

    func append(message: String) {
        messages.append(StubMessage(id: messages.count, sender: "Neo", message: message))
        objectWillChange.send()
    }
}

let conversationTitle = "Morpheus"

struct ConversationView: View {
    init() {
        UITableView.appearance().separatorStyle = .none
    }

    @ObservedObject var messageStore = StubMessageStore()

    var body: some View {
        VStack {
            List(messageStore.messages) { message in
                MessageView(message: message)
            }

            MessageComposerView()
                .onSend { self.messageStore.append(message: $0) }
                .padding(.horizontal)
                .padding(.bottom, 10)
        }
        .navigationBarTitle(Text(conversationTitle), displayMode: .inline)
        .keyboardObserving()
    }
}

struct ConversationView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ConversationView()
                .accentColor(.purple)
                .navigationBarTitle("Morpheus", displayMode: .inline)
        }
    }
}
