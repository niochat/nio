import SwiftUI

struct BorderedMessageView<Model>: View where Model: MessageViewModelProtocol {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.colorSchemeContrast) var colorSchemeContrast
    @Environment(\.sizeCategory) var sizeCategory
    @Environment(\.userId) var userId

    var model: Model
    var contextMenuModel: EventContextMenuModel
    var connectedEdges: ConnectedEdges
    var isEdited = false

    var isMe: Bool {
        model.sender == userId
    }

    private var linkColor: UIColor {
        if isMe {
            return UIColor(
                hue: 280.0 / 360.0,
                saturation: 1.0,
                brightness: 0.33,
                alpha: 1.0
            )
        } else {
            return UIColor.blue
        }
    }

    var textColor: Color {
        if isMe {
            return .lightText(for: colorScheme, with: colorSchemeContrast)
        } else {
            return .primaryText(for: colorScheme, with: colorSchemeContrast)
        }
    }

    var backgroundColor: Color {
        if isMe {
            return .accentColor
        } else {
            return .borderedMessageBackground
        }
    }

    var gradient: LinearGradient {
        let color: Color = backgroundColor
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

    var background: some View {
        let largeRadius: CGFloat = 15.0 * sizeCategory.scalingFactor
        let smallRadius: CGFloat = 5.0 * sizeCategory.scalingFactor

        // We construct a left-aligned shape:
        return IndividuallyRoundedRectangle(
            topLeft: connectedEdges.contains(.topEdge) ? smallRadius : largeRadius,
            topRight: largeRadius,
            bottomLeft: connectedEdges.contains(.bottomEdge) ? smallRadius : largeRadius,
            bottomRight: largeRadius
        )
        .fill(gradient).opacity(0.9)
        // and flip it in case it's meant to be right-aligned:
        .scaleEffect(x: isMe ? -1.0 : 1.0, y: 1.0, anchor: .center)
    }

    var timestampView: some View {
        Text(model.timestamp)
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(10)
    }

    var markdownView: some View {
        MarkdownText(
            markdownString: model.text
        ) { url in
            print("Tapped URL:", url)
        }
    }

    var senderView: some View {
        if model.showSender
            && !isMe
            && (connectedEdges.isEmpty || connectedEdges == .bottomEdge) {
                return AnyView(
                    Text(model.sender)
                        .font(.caption)
                )
        } else {
            return AnyView(EmptyView())
        }
    }

    var editBadgeView: some View {
        let foregroundColor = Color.backgroundColor(for: colorScheme)
        return BadgeView(
            image: Image(Asset.Badge.edited.name),
            foregroundColor: foregroundColor,
            backgroundColor: backgroundColor
        )
    }

    var body: some View {
        // Vertically stack sender, message, reactions & timestamp:
        //
        // ```
        // @sender
        // ┌───────────────────────────┐
        // │ Message                   │
        // └───────────────────────────┘
        // ┌───────────┐
        // │ Reactions │
        // └───────────┘
        //                    timestamp
        // ```
        VStack(alignment: isMe ? .trailing : .leading, spacing: 3) {
            senderView
            // ZStack for drawing badges (e.g. "edited") over the message's edge, if appropriate:
            //
            // ```
            //   ┌──────────────────────────────┐
            //   │ Lorem ipsum dolor sit amet   │
            //   │ consectetur adipiscing elit. │
            // ┌─┴─┐                            │
            // │   ├────────────────────────────┘
            // └───┘
            // ```
            ZStack(alignment: isMe ? .bottomLeading : .bottomTrailing) {
                markdownView
                    .padding(5)
                    .background(background)
                    .contextMenu(ContextMenu(menuItems: {
                        EventContextMenu(model: contextMenuModel)
                    }))
                if isEdited {
                    self.editBadgeView
                        .offset(x: isMe ? -5 : 5, y: 5)
                }
            }
            GroupedReactionsView(reactions: model.reactions)
            if !connectedEdges.contains(.bottomEdge) {
                // It's the last message in a group, so show a timestamp:
                timestampView
            }
        }
    }
}

struct BorderedMessageView_Previews: PreviewProvider {
    private struct MessageViewModel: MessageViewModelProtocol {
        var id: String
        var text: String
        var sender: String
        var showSender: Bool
        var timestamp: String
        var reactions: [Reaction]
    }

    static func lone(sender: String,
                     text: String = "Lorem ipsum dolor sit amet!",
                     userId: String,
                     showSender: Bool,
                     reactions: [Reaction]
    ) -> some View {
        BorderedMessageView(
            model: MessageViewModel(
                id: "0",
                text: text,
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
            BorderedMessageView(
                model: MessageViewModel(
                    id: "0",
                    text: "This is a message",
                    sender: sender,
                    showSender: showSender,
                    timestamp: "12:29",
                    reactions: reactions
                ),
                contextMenuModel: .previewModel,
                connectedEdges: [.bottomEdge]
            )
            BorderedMessageView(
                model: MessageViewModel(
                    id: "0",
                    text: "that's quickly followed",
                    sender: sender,
                    showSender: showSender,
                    timestamp: "12:29",
                    reactions: reactions
                ),
                contextMenuModel: .previewModel,
                connectedEdges: [.topEdge, .bottomEdge]
            )
            BorderedMessageView(
                model: MessageViewModel(
                    id: "0",
                    text: "by some more messages.",
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

    // swiftlint:disable identifier_name
    static var 💜 = Reaction(sender: "Jane", timestamp: Date(), reaction: "💜")
    static var 🚀 = Reaction(sender: "Jane", timestamp: Date(), reaction: "🚀")
    static var 👍 = Reaction(sender: "John", timestamp: Date(), reaction: "👍")
    // swiftlint:enable identifier_name

    static var previews: some View {
        Group {
            enumeratingColorSchemes {
                lone(sender: "John Doe",
                     text: "Lorem",
                     userId: "Jane Doe",
                     showSender: false,
                     reactions: [💜, 💜, 👍])
            }
            .previewDisplayName("Incoming Lone Messages")

            enumeratingColorSchemes {
                lone(sender: "Jane Doe",
                     userId: "Jane Doe",
                     showSender: false,
                     reactions: [🚀, 👍])
            }
            .previewDisplayName("Outgoing Lone Messages")

            grouped(sender: "John Doe",
                    userId: "Jane Doe",
                    showSender: true,
                    reactions: [💜, 💜, 🚀, 👍])
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
                     reactions: [🚀])
            }
            .previewDisplayName("Incoming Messages")
        }
        .accentColor(.purple)
        .previewLayout(.sizeThatFits)
    }
}
