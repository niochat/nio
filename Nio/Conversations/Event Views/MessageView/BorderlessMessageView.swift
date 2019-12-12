import SwiftUI

struct BorderlessMessageView<Model>: View where Model: MessageViewModelProtocol {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.sizeCategory) var sizeCategory: ContentSizeCategory
    @Environment(\.userID) var userID

    var model: Model
    var bounds: GroupBounds

    private var isMe: Bool {
        model.sender == userID
    }

    var timestampView: some View {
        Text(model.timestamp)
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(10)
    }

    var contentView: some View {
        Text(model.text)
            .font(.system(size: 60 * sizeCategory.scalingFactor))
    }

    var body: some View {
        if isMe {
            return AnyView(HStack {
                Spacer()
                timestampView
                contentView
            })
        } else {
            return AnyView(HStack {
                contentView
                timestampView
                Spacer()
            })
        }
    }
}
