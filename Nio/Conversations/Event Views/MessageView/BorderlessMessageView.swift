import SwiftUI

struct BorderlessMessageView<Model>: View where Model: MessageViewModelProtocol {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.sizeCategory) var sizeCategory: ContentSizeCategory
    @Environment(\.userID) var userID

    var model: Model
    var displayStyle: MessageDisplayStyle

    private var isMe: Bool {
        model.sender == userID
    }

    private var topPadding: CGFloat {
        displayStyle.hasGapAbove ? 5.0 : 0.0
    }

    private var bottomPadding: CGFloat {
        displayStyle.hasGapBelow ? 5.0 : 0.0
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

    var body: some View {
        if isMe {
            return AnyView(HStack {
                timestampView
                contentView
            })
        } else {
            return AnyView(HStack {
                contentView
                timestampView
            })
        }
    }
}

struct BorderlessMessageView_Previews: PreviewProvider {
    private struct MessageViewModel: MessageViewModelProtocol {
        var id: String
        var text: String
        var sender: String
        var timestamp: String
    }

    static func lone(sender: String, userID: String) -> some View {
        BorderlessMessageView(
            model: MessageViewModel(
                id: "0",
                text: "🐧",
                sender: sender,
                timestamp: "12:29"
            ),
            displayStyle: MessageDisplayStyle(
                hasGapAbove: true,
                hasGapBelow: true
            )
        )
            .padding()
            .environment(\.userID, userID)
    }

    static func grouped(sender: String, userID: String) -> some View {
        let alignment: HorizontalAlignment = (sender == userID) ? .trailing : .leading

        return VStack(alignment: alignment, spacing: 3) {
            BorderlessMessageView(
                model: MessageViewModel(
                    id: "0",
                    text: "🐶",
                    sender: sender,
                    timestamp: "12:29"
                ),
                displayStyle: MessageDisplayStyle(
                    hasGapAbove: true,
                    hasGapBelow: false
                )
            )
            BorderlessMessageView(
                model: MessageViewModel(
                    id: "0",
                    text: "🦊",
                    sender: sender,
                    timestamp: "12:29"
                ),
                displayStyle: MessageDisplayStyle(
                    hasGapAbove: false,
                    hasGapBelow: false
                )
            )
            BorderlessMessageView(
                model: MessageViewModel(
                    id: "0",
                    text: "🐻",
                    sender: sender,
                    timestamp: "12:29"
                ),
                displayStyle: MessageDisplayStyle(
                    hasGapAbove: false,
                    hasGapBelow: true
                )
            )
        }
        .padding()
        .environment(\.userID, userID)
    }

    static var previews: some View {
        Group {
            enumeratingColorSchemes {
                lone(sender: "John Doe", userID: "Jane Doe")
            }
            .previewDisplayName("Incoming Lone Messages")

            enumeratingColorSchemes {
                lone(sender: "Jane Doe", userID: "Jane Doe")
            }
            .previewDisplayName("Outgoing Lone Messages")

            grouped(sender: "John Doe", userID: "Jane Doe")
            .previewDisplayName("Incoming Grouped Messages")

            grouped(sender: "Jane Doe", userID: "Jane Doe")
            .previewDisplayName("Outgoing Grouped Messages")

            enumeratingSizeCategories {
                lone(sender: "John Doe", userID: "Jane Doe")
            }
            .previewDisplayName("Incoming Messages")
        }
        .accentColor(.purple)
        .previewLayout(.sizeThatFits)
    }
}
