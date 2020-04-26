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

    private var isMe: Bool {
        model.sender == userId
    }

    var textColor: Color {
        if model.sender == userId {
            return .lightText(for: colorScheme, with: colorSchemeContrast)
        }
        return .primaryText(for: colorScheme, with: colorSchemeContrast)
    }

    var backgroundColor: Color {
        guard model.sender == userId else {
            return .borderedMessageBackground
        }
        return .accentColor
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

    var bodyView: some View {
        Text(model.text)
            .foregroundColor(textColor)
    }

    var editedBodyView: some View {
        Text(model.text + " ")
            .foregroundColor(textColor)
        + Text("(" + L10n.Event.edit + ")")
            .font(.caption)
            .foregroundColor(textColor
                .opacity(colorSchemeContrast == .standard ? 0.5 : 1.0))
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

    var timestampView: some View {
        Text(model.timestamp)
        .font(.caption)
        .foregroundColor(textColor)
        .opacity(colorSchemeContrast == .standard ? 0.5 : 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            senderView
            VStack(alignment: isMe ? .trailing : .leading, spacing: 3) {
                VStack(alignment: isMe ? .trailing : .leading, spacing: 5) {
                    if isEdited {
                        editedBodyView
                    } else {
                        bodyView
                    }
                    if !connectedEdges.contains(.bottomEdge) {
                        // It's the last message in a group, so show a timestamp:
                        timestampView
                    }
                }
                .padding(10)
                .background(background)
                .contextMenu(ContextMenu(menuItems: {
                    EventContextMenu(model: contextMenuModel)
                }))

                GroupedReactionsView(reactions: model.reactions)
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
