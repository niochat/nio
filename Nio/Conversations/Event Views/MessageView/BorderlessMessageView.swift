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

    var gradient: LinearGradient {
        let color: Color = .borderedMessageBackground
        let colors: [Color]
        if colorScheme == .dark {
            colors = [color.opacity(1.0), color.opacity(0.85)]
        } else {
            colors = [color.opacity(0.85), color.opacity(1.0)]
        }
        return LinearGradient(
            gradient: Gradient(colors: colors),
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var reactionsView: some View {
        Group {
            if model.reactions.isEmpty {
                EmptyView()
            } else {
                HStack(spacing: 3) {
                    ForEach(model.groupedReactions, id: \.0) { (emoji, count) in
                        HStack(spacing: 1) {
                            Text(emoji)
                                .font(.caption)
                            Text(String(count))
                                .font(.callout)
                        }
                        .padding(.vertical, 2)
                        .padding(.horizontal, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(self.gradient)
                                .shadow(radius: 1)
                        )
                    }
                }
            }
        }
    }

    var bodyView: some View {
        if isMe {
            return AnyView(
                VStack(alignment: .trailing, spacing: 0) {
                    HStack {
                        if !connectedEdges.contains(.bottomEdge) {
                            // It's the last message in a group, so show a timestamp:
                            timestampView
                        }
                        contentView
                    }
                    reactionsView
                }
            )
        } else {
            return AnyView(
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        contentView
                        if !connectedEdges.contains(.bottomEdge) {
                            // It's the last message in a group, so show a timestamp:
                            timestampView
                        }
                    }
                    reactionsView
                }
            )
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
        var showSender: Bool
        var timestamp: String
        var reactions: [String]
    }

    static func lone(sender: String,
                     userId: String,
                     showSender: Bool,
                     reactions: [String]
    ) -> some View {
        BorderlessMessageView(
            model: MessageViewModel(
                id: "0",
                text: "🐧",
                sender: sender,
                showSender: showSender,
                timestamp: "12:29",
                reactions: reactions
            ),
            connectedEdges: []
        )
            .padding()
            .environment(\.userId, userId)
    }

    static func grouped(sender: String,
                        userId: String,
                        showSender: Bool,
                        reactions: [String]
    ) -> some View {
        let alignment: HorizontalAlignment = (sender == userId) ? .trailing : .leading

        return VStack(alignment: alignment, spacing: 3) {
            BorderlessMessageView(
                model: MessageViewModel(
                    id: "0",
                    text: "🐶",
                    sender: sender,
                    showSender: showSender,
                    timestamp: "12:29",
                    reactions: reactions
                ),
                connectedEdges: [.bottomEdge]
            )
            BorderlessMessageView(
                model: MessageViewModel(
                    id: "0",
                    text: "🦊",
                    sender: sender,
                    showSender: showSender,
                    timestamp: "12:29",
                    reactions: reactions
                ),
                connectedEdges: [.topEdge, .bottomEdge]
            )
            BorderlessMessageView(
                model: MessageViewModel(
                    id: "0",
                    text: "🐻",
                    sender: sender,
                    showSender: showSender,
                    timestamp: "12:29",
                    reactions: reactions
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
                lone(sender: "John Doe",
                     userId: "Jane Doe",
                     showSender: false,
                     reactions: ["❤️", "🥳", "🥳"])
            }
            .previewDisplayName("Incoming Lone Messages")

            enumeratingColorSchemes {
                lone(sender: "Jane Doe",
                     userId: "Jane Doe",
                     showSender: false,
                     reactions: ["🥳"])
            }
            .previewDisplayName("Outgoing Lone Messages")

            grouped(sender: "John Doe",
                    userId: "Jane Doe",
                    showSender: true,
                    reactions: ["💜", "💜"])
            .previewDisplayName("Incoming Grouped Messages")

            grouped(sender: "Jane Doe",
                    userId: "Jane Doe",
                    showSender: false,
                    reactions: [])
            .previewDisplayName("Outgoing Grouped Messages")

            enumeratingSizeCategories {
                lone(sender: "John Doe",
                     userId: "Jane Doe",
                     showSender: false,
                     reactions: [])
            }
            .previewDisplayName("Incoming Messages")
        }
        .accentColor(.purple)
        .previewLayout(.sizeThatFits)
    }
}
