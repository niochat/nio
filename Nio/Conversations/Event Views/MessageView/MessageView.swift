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
        var timestamp: String
    }

    static func lone(sender: String, userId: String) -> some View {
        BorderlessMessageView(
            model: MessageViewModel(
                id: "0",
                text: "🐧",
                sender: sender,
                timestamp: "12:29"
            ),
            connectedEdges: []
        )
            .padding()
            .environment(\.userId, userId)
    }

    static func grouped(sender: String, userId: String) -> some View {
        let alignment: HorizontalAlignment = (sender == userId) ? .trailing : .leading

        return VStack(alignment: alignment, spacing: 3) {
            BorderlessMessageView(
                model: MessageViewModel(
                    id: "0",
                    text: "🐶",
                    sender: sender,
                    timestamp: "12:29"
                ),
                connectedEdges: [.bottomEdge]
            )
            BorderlessMessageView(
                model: MessageViewModel(
                    id: "0",
                    text: "🦊",
                    sender: sender,
                    timestamp: "12:29"
                ),
                connectedEdges: [.topEdge, .bottomEdge]
            )
            BorderlessMessageView(
                model: MessageViewModel(
                    id: "0",
                    text: "🐻",
                    sender: sender,
                    timestamp: "12:29"
                ),
                connectedEdges: [.topEdge]
            )
        }
        .padding()
        .environment(\.userId, userId)
    }

    static var previews: some View {
        Group {
            enumeratingColorSchemes {
                lone(sender: "John Doe", userId: "Jane Doe")
            }
            .previewDisplayName("Incoming Lone Messages")

            enumeratingColorSchemes {
                lone(sender: "Jane Doe", userId: "Jane Doe")
            }
            .previewDisplayName("Outgoing Lone Messages")

            grouped(sender: "John Doe", userId: "Jane Doe")
            .previewDisplayName("Incoming Grouped Messages")

            grouped(sender: "Jane Doe", userId: "Jane Doe")
            .previewDisplayName("Outgoing Grouped Messages")

            enumeratingSizeCategories {
                lone(sender: "John Doe", userId: "Jane Doe")
            }
            .previewDisplayName("Incoming Messages")
        }
        .accentColor(.purple)
        .previewLayout(.sizeThatFits)
    }
}
