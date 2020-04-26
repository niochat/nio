import SwiftUI

struct BorderlessMessageView<Model>: View where Model: MessageViewModelProtocol {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.colorSchemeContrast) var colorSchemeContrast
    @Environment(\.sizeCategory) var sizeCategory
    @Environment(\.userId) var userId

    var model: Model
    var contextMenuModel: EventContextMenuModel
    var connectedEdges: ConnectedEdges
    var isEdited = false

    var textColor: Color {
        if model.sender == userId {
            return .lightText(for: colorScheme, with: colorSchemeContrast)
        }
        return .primaryText(for: colorScheme, with: colorSchemeContrast)
    }

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

    var editedView: some View {
        Text("(" + L10n.Event.edit + ")")
            .font(.caption)
            .foregroundColor(textColor)
            .opacity(colorSchemeContrast == .standard ? 0.5 : 1.0)
    }

    var contentView: some View {
        emojiView
    }

    var contentEditedView: some View {
        VStack {
            emojiView
            editedView
        }
    }

    var senderView: some View {
        if model.showSender && !isMe && (connectedEdges == .bottomEdge || connectedEdges.isEmpty) {
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

    var bodyView: some View {
        if isMe {
            return AnyView(
                VStack(alignment: .trailing, spacing: 0) {
                    HStack {
                        if !connectedEdges.contains(.bottomEdge) {
                            // It's the last message in a group, so show a timestamp:
                            timestampView
                        }
                        if isEdited {
                            contentEditedView
                        } else {
                            contentView
                        }
                    }
                    GroupedReactionsView(reactions: model.reactions)
                }
            )
        } else {
            return AnyView(
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        if isEdited {
                            contentEditedView
                        } else {
                            contentView
                        }
                        if !connectedEdges.contains(.bottomEdge) {
                            // It's the last message in a group, so show a timestamp:
                            timestampView
                        }
                    }
                    GroupedReactionsView(reactions: model.reactions)
                }
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            senderView
            bodyView
            .contextMenu(ContextMenu(menuItems: {
                EventContextMenu(model: contextMenuModel)
            }))
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
        var reactions: [Reaction]
    }

    // swiftlint:disable identifier_name
    static var 💜 = Reaction(sender: "Jane", timestamp: Date(), reaction: "💜")
    static var 🚀 = Reaction(sender: "Jane", timestamp: Date(), reaction: "🚀")
    static var 👍 = Reaction(sender: "John", timestamp: Date(), reaction: "👍")
    // swiftlint:enable identifier_name

    static func lone(sender: String,
                     userId: String,
                     showSender: Bool,
                     reactions: [Reaction]
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
            contextMenuModel: .previewModel,
            connectedEdges: []
        )
            .padding()
            .environment(\.userId, userId)
    }

    static func grouped(sender: String,
                        userId: String,
                        showSender: Bool,
                        reactions: [Reaction]
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
                contextMenuModel: .previewModel,
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
                contextMenuModel: .previewModel,
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
                contextMenuModel: .previewModel,
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
                     reactions: [💜, 💜, 🚀, 👍])
            }
            .previewDisplayName("Incoming Lone Messages")

            enumeratingColorSchemes {
                lone(sender: "Jane Doe",
                     userId: "Jane Doe",
                     showSender: false,
                     reactions: [🚀])
            }
            .previewDisplayName("Outgoing Lone Messages")

            grouped(sender: "John Doe",
                    userId: "Jane Doe",
                    showSender: true,
                    reactions: [💜, 💜])
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
