import SwiftUI

struct ReactionGroupView: View {
    private let text: String
    private let count: Int

    private let backgroundColor: Color

    init(text: String, count: Int, backgroundColor: Color) {
        assert(count > 0, "Expected non-zero positive integer")

        self.text = text
        self.count = count
        self.backgroundColor = backgroundColor
    }

    var body: some View {
        return HStack(spacing: 1) {
            Text(self.text)
            Text(String(self.count))
        }
        .font(.footnote)
        .padding(EdgeInsets(top: 4.0, leading: 8.0, bottom: 4.0, trailing: 8.0))
        .background(
            RoundedRectangle(cornerRadius: 30)
                .fill(self.backgroundColor)
        )
    }
}

struct ReactionGroupView_Previews: PreviewProvider {
    static var reactionView: some View {
        ReactionGroupView(
            text: "💩",
            count: 42,
            backgroundColor: Color.borderedMessageBackground
        )
    }

    static var previews: some View {
        Group {
            enumeratingColorSchemes {
                reactionView
                    .padding()
                    .previewLayout(.sizeThatFits)
            }
        }
    }
}
