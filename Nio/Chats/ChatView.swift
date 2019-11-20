import SwiftUI

struct StubMessage: Identifiable {
    var id: Int
    var sender: String
    var message: String

    var isMe: Bool {
        sender == "Neo"
    }

    var textColor: Color {
        if isMe {
            return .white
        }
        return .black
    }

    var backgroundColor: Color {
        if isMe {
            return .purple
        }
        return Color(#colorLiteral(red: 0.8979603648, green: 0.8980901837, blue: 0.9175375104, alpha: 1))
    }
}

//swiftlint:disable line_length
let messages = [
    StubMessage(id: 0, sender: "Morpheus", message: "This line is tapped, so I must be brief. They got to you first, but they’ve underestimated how important you are. If they knew what I know, you’d probably be dead."),
    StubMessage(id: 1, sender: "Neo", message: "What are you talking about. What… what is happening to me?"),
    StubMessage(id: 2, sender: "Morpheus", message: "You are The One, Neo. You see, you may have spent the last few years looking for me, but I’ve spent my entire life looking for you. Now do you still want to meet?"),
    StubMessage(id: 3, sender: "Neo", message: "Yes."),
    StubMessage(id: 4, sender: "Morpheus", message: "Then go to the Adams street Bridge.")
]

let conversationTitle = "Morpheus"

struct ChatView: View {
    init() {
        UITableView.appearance().separatorStyle = .none
    }

    var body: some View {
        VStack {
            List(messages) { message in
                MessageView(message: message)
            }

            MessageComposerView()
                .padding()
        }
        .navigationBarTitle(Text(conversationTitle), displayMode: .inline)
    }
}

struct MessageView: View {
    var message: StubMessage

    var body: some View {
        HStack {
            if message.isMe {
                Spacer()
            }
            VStack(alignment: .leading) {
                if !message.isMe {
                    Text(message.sender)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.bottom, 5)
                }
                Text(message.message)
                    .foregroundColor(message.textColor)
                    .padding(10)
                    .background(message.backgroundColor)
                    .cornerRadius(15)
            }
        }
    }
}

struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ChatView()
                .accentColor(.purple)
                .navigationBarTitle("Morpheus", displayMode: .inline)
        }
    }
}
