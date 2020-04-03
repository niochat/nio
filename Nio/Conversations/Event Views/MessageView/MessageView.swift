import SwiftUI

struct MessageView<Model>: View where Model: MessageViewModelProtocol {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.sizeCategory) var sizeCategory: ContentSizeCategory
    @Environment(\.userId) var userId

    @Binding var model: Model
    var connectedEdges: ConnectedEdges

    private var isMe: Bool {
        model.sender == userId
    }

    var body: some View {
        if model.isEmoji {
            let messageView = BorderlessMessageView(
                model: model,
                connectedEdges: connectedEdges
            )
            if isMe {
                return AnyView(HStack {
                    Spacer()
                    messageView
                })
            } else {
                return AnyView(HStack {
                    messageView
                    Spacer()
                })
            }
        } else {
            let messageView = BorderedMessageView(
                model: model,
                connectedEdges: connectedEdges
            )
            if isMe {
                return AnyView(HStack {
                    Spacer()
                    messageView
                })
            } else {
                return AnyView(HStack {
                    messageView
                    Spacer()
                })
            }
        }
    }
}

struct MessageView_Previews: PreviewProvider {
    private struct MessageViewModel: MessageViewModelProtocol {
        var id: String
        var text: String
        var sender: String
        var showSender: Bool
        var timestamp: String
        var reactions: [String]
    }

    static func message(text: String,
                        sender: String,
                        userId: String,
                        showSender: Bool,
                        reactions: [String]
    ) -> some View {
        MessageView(
            model: .constant(MessageViewModel(
                id: "0",
                text: text,
                sender: sender,
                showSender: showSender,
                timestamp: "12:29",
                reactions: reactions
            )),
            connectedEdges: []
        )
            .padding()
            .environment(\.userId, userId)
    }

    static var previews: some View {
        Group {
            message(
                text: "Hi there!",
                sender: "John Doe",
                userId: "Jane Doe",
                showSender: true,
                reactions: []
            )

            message(
                text: "👋",
                sender: "John Doe",
                userId: "Jane Doe",
                showSender: false,
                reactions: []
            )
        }
        .accentColor(.purple)
        .previewLayout(.sizeThatFits)
    }
}
