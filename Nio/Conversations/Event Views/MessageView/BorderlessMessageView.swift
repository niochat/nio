import SwiftUI

struct BorderlessMessageView<Model>: View where Model: MessageViewModelProtocol {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.sizeCategory) var sizeCategory: ContentSizeCategory
    @Environment(\.userId) var userId

    var model: Model
    var connectedEdges: ConnectedEdges

    private var isMe: Bool {
        model.sender == userId
    }

    private var topPadding: CGFloat {
        connectedEdges.contains(.topEdge) ? 0.0 : 5.0
    }

    private var bottomPadding: CGFloat {
        connectedEdges.contains(.bottomEdge) ? 0.0 : 5.0
    }

    var timestampView: some View {
        Text(model.timestamp)
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(10)
    }

    var emojiView: some View {
        Text(model.text)
        .font(.system(size: 60 * sizeCategory.scalingFactor))
    }

    var contentView: some View {
        emojiView
            .padding(.top, topPadding)
            .padding(.bottom, bottomPadding)
    }

    var senderView: some View {
        if model.showSender && !isMe && connectedEdges == .bottomEdge {
            return AnyView(
                Text(model.sender)
                    .font(.caption)
            )
        } else {
            return AnyView(EmptyView())
        }
    }

    var bodyView: some View {
        if isMe {
            return AnyView(HStack {
                if !connectedEdges.contains(.bottomEdge) {
                    // It's the last message in a group, so show a timestamp:
                    timestampView
                }
                contentView
            })
        } else {
            return AnyView(HStack {
                contentView
                if !connectedEdges.contains(.bottomEdge) {
                    // It's the last message in a group, so show a timestamp:
                    timestampView
                }
            })
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            senderView
            bodyView
        }
    }
}

struct BorderlessMessageView_Previews: PreviewProvider {
    private struct MessageViewModel: MessageViewModelProtocol {
        var id: String
        var text: String
        var sender: String
        var timestamp: String
        var showSender: Bool
    }

    static func lone(sender: String, userId: String, showSender: Bool) -> some View {
        BorderlessMessageView(
            model: MessageViewModel(
                id: "0",
                text: "🐧",
                sender: sender,
                timestamp: "12:29",
                showSender: showSender
            ),
            connectedEdges: []
        )
            .padding()
            .environment(\.userId, userId)
    }

    static func grouped(sender: String, userId: String, showSender: Bool) -> some View {
        let alignment: HorizontalAlignment = (sender == userId) ? .trailing : .leading

        return VStack(alignment: alignment, spacing: 3) {
            BorderlessMessageView(
                model: MessageViewModel(
                    id: "0",
                    text: "🐶",
                    sender: sender,
                    timestamp: "12:29",
                    showSender: showSender
                ),
                connectedEdges: [.bottomEdge]
            )
            BorderlessMessageView(
                model: MessageViewModel(
                    id: "0",
                    text: "🦊",
                    sender: sender,
                    timestamp: "12:29",
                    showSender: showSender
                ),
                connectedEdges: [.topEdge, .bottomEdge]
            )
            BorderlessMessageView(
                model: MessageViewModel(
                    id: "0",
                    text: "🐻",
                    sender: sender,
                    timestamp: "12:29",
                    showSender: showSender
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
                lone(sender: "John Doe", userId: "Jane Doe", showSender: false)
            }
            .previewDisplayName("Incoming Lone Messages")

            enumeratingColorSchemes {
                lone(sender: "Jane Doe", userId: "Jane Doe", showSender: false)
            }
            .previewDisplayName("Outgoing Lone Messages")

            grouped(sender: "John Doe", userId: "Jane Doe", showSender: true)
            .previewDisplayName("Incoming Grouped Messages")

            grouped(sender: "Jane Doe", userId: "Jane Doe", showSender: false)
            .previewDisplayName("Outgoing Grouped Messages")

            enumeratingSizeCategories {
                lone(sender: "John Doe", userId: "Jane Doe", showSender: false)
            }
            .previewDisplayName("Incoming Messages")
        }
        .accentColor(.purple)
        .previewLayout(.sizeThatFits)
    }
}
