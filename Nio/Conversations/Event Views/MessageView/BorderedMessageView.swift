import SwiftUI

struct BorderedMessageView<Model>: View where Model: MessageViewModelProtocol {
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    @Environment(\.sizeCategory) var sizeCategory: ContentSizeCategory
    @Environment(\.userID) var userID

    var model: Model
    var bounds: GroupBounds

    private var isMe: Bool {
        model.sender == userID
    }

    var textColor: Color {
        guard model.sender == userID else {
            return .primary
        }
        return .white
    }

    var backgroundColor: Color {
        guard model.sender == userID else {
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

        var topLeft: CGFloat = largeRadius
        var topRight: CGFloat = largeRadius
        var bottomLeft: CGFloat = largeRadius
        var bottomRight: CGFloat = largeRadius

        // We're right beneath another message in a group:
        if !bounds.contains(.isAtStartOfGroup) {
            if isMe {
                topRight = smallRadius
            } else {
                topLeft = smallRadius
            }
        }

        // We're right above another message in a group:
        if !bounds.contains(.isAtEndOfGroup) {
            if isMe {
                bottomRight = smallRadius
            } else {
                bottomLeft = smallRadius
            }
        }

        return IndividuallyRoundedRectangle(
            topLeft: topLeft,
            topRight: topRight,
            bottomLeft: bottomLeft,
            bottomRight: bottomRight
        )
            .fill(gradient).opacity(0.9)
    }

    var bodyView: some View {
        Text(model.text)
        .foregroundColor(textColor)
    }

    var timestampView: some View {
        Text(model.timestamp)
        .font(.caption)
        .foregroundColor(textColor).opacity(0.5)
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 5) {
            bodyView
            if bounds.contains(.isAtEndOfGroup) {
                HStack {
                    timestampView
                }
            }
        }
        .padding(10)
        .background(background)
    }
}

struct BorderedMessageView_Previews: PreviewProvider {
    private struct MessageViewModel: MessageViewModelProtocol {
        var id: String
        var text: String
        var sender: String
        var timestamp: String
    }

    static func lone(sender: String, userID: String) -> some View {
        BorderedMessageView(
            model: MessageViewModel(
                id: "0",
                text: "Lorem ipsum dolor sit amet!",
                sender: sender,
                timestamp: "12:29"
            ),
            bounds: [.isLone]
        )
            .padding()
            .environment(\.userID, userID)
    }

    static func grouped(sender: String, userID: String) -> some View {
        let alignment: HorizontalAlignment = (sender == userID) ? .trailing : .leading

        return VStack(alignment: alignment, spacing: 3) {
            BorderedMessageView(
                model: MessageViewModel(
                    id: "0",
                    text: "This is a message",
                    sender: sender,
                    timestamp: "12:29"
                ),
                bounds: [.isAtStartOfGroup])
            BorderedMessageView(
                model: MessageViewModel(
                    id: "0",
                    text: "that's quickly followed",
                    sender: sender,
                    timestamp: "12:29"
                ),
                bounds: []
            )
            BorderedMessageView(
                model: MessageViewModel(
                    id: "0",
                    text: "by some more messages.",
                    sender: sender,
                    timestamp: "12:29"
                ),
                bounds: [.isAtEndOfGroup]
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
