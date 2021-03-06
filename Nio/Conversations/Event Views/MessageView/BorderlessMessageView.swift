import SwiftUI
import MatrixSDK

import NioKit

struct BorderlessMessageView<Model>: View where Model: MessageViewModelProtocol {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.sizeCategory) private var sizeCategory
    @Environment(\.userId) private var userId

    let model: Model
    let contextMenuModel: EventContextMenuModel
    let connectedEdges: ConnectedEdges
    var isEdited = false

    private var isMe: Bool {
        model.sender == userId
    }

    private var timestampView: some View {
        Text(model.timestamp)
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(10)
    }

    private var emojiView: some View {
        Text(model.text)
        .font(.system(size: 60 * sizeCategory.scalingFactor))
    }

    private var contentView: some View {
        emojiView
    }

    private var conditionalBadgedContentView: some View {
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

    private var gradient: LinearGradient {
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

    private var backgroundColor: Color {
        guard model.sender == userId else {
            return .borderedMessageBackground
        }
        return .accentColor
    }

    private var editBadgeView: some View {
        let foregroundColor = Color.backgroundColor(for: colorScheme)
        return BadgeView(image: Image(Asset.Badge.edited.name),
                         foregroundColor: foregroundColor,
                         backgroundColor: backgroundColor)
            .frame(width: 20.0, height: 20.0)
    }

    private var bodyView: some View {
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
        var sentState: MXEventSentState
        var showSender: Bool
        var timestamp: String
        var reactions: [Reaction]
    }

    // swiftlint:disable identifier_name
    static var 💜 = Reaction(id: "0", sender: "Jane", timestamp: Date(), reaction: "💜")
    static var 🚀 = Reaction(id: "1", sender: "Jane", timestamp: Date(), reaction: "🚀")
    static var 👍 = Reaction(id: "2", sender: "John", timestamp: Date(), reaction: "👍")
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
                sentState: MXEventSentStateSent,
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
                    sentState: MXEventSentStateSent,
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
                    sentState: MXEventSentStateSent,
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
                    sentState: MXEventSentStateSent,
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
