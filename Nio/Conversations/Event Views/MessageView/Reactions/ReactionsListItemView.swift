import SwiftUI

struct ReactionsListItemView: View {
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    @Environment(\.colorSchemeContrast) var colorSchemeContrast: ColorSchemeContrast
    @Environment(\.userId) var userId

    let reaction: Reaction

    private var timestamp: String {
        Formatter.string(
            for: self.reaction.timestamp,
            dateStyle: .short,
            timeStyle: .short
        )
    }

    var body: some View {
        HStack {
            Text(self.reaction.reaction)
            Text(self.reaction.sender)
            Spacer()
            Text(timestamp)
                .font(.footnote)
        }
    }
}

struct ReactionsListItemView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            enumeratingColorSchemes {
                ReactionsListItemView(
                    reaction: Reaction(
                        id: "0",
                        sender: "Jane Doe",
                        timestamp: Date(),
                        reaction: "❤️"
                    )
                )
                    .padding()
            }
        }
            .previewLayout(.sizeThatFits)
    }
}
