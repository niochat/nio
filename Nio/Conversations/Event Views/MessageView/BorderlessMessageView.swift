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

    var isMe: Bool {
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
        Text("(" + L10n.Event.edited + ")")
            .font(.caption)
            .foregroundColor(textColor)
            .opacity(colorSchemeContrast == .standard ? 0.5 : 1.0)
    }

    var contentView: some View {
        emojiView
    }

    var conditionalBadgedContentView: some View {
        ZStack(alignment: isMe ? .bottomLeading : .bottomTrailing) {
            contentView
            if isEdited {
                self.editBadgeView
                    .offset(x: isMe ? -5 : 5, y: 5)
            }
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

    var backgroundColor: Color {
        guard model.sender == userId else {
            return .borderedMessageBackground
        }
        return .accentColor
    }

    var editBadgeView: some View {
        let foregroundColor = Color.backgroundColor(for: colorScheme)
        return BadgeView(
            image: Image(Asset.Badge.edited.name),
            foregroundColor: foregroundColor,
            backgroundColor: backgroundColor
        )
    }

    var bodyView: some View {
        VStack(alignment: isMe ? .trailing : .leading, spacing: 0) {
            if isMe {
                HStack {
                    if !self.connectedEdges.contains(.bottomEdge) {
                        self.timestampView
                   }
                    self.conditionalBadgedContentView
                }
            } else {
                HStack {
                    self.conditionalBadgedContentView
                    if !self.connectedEdges.contains(.bottomEdge) {
                        self.timestampView
                    }
                }
            }

            GroupedReactionsView(reactions: model.reactions)
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
