import SwiftUI

struct ReactionPicker: View {
    let emoji = ["👍", "👎", "😄", "🎉", "❤️", "🚀", "👀"]

    let picked: (String) -> Void

    var body: some View {
        VStack {
            Text(verbatim: L10n.ReactionPicker.title)
                .foregroundColor(.gray)
                .font(.headline)
                .padding(.bottom, 30)
            HStack(spacing: 10) {
                ForEach(emoji, id: \.self) { emoji in
                    Button(action: { self.picked(emoji) },
                           label: {
                        Text(emoji)
                            .font(.largeTitle)
                    })
                }
            }
        }
    }
}

struct ReactionPicker_Previews: PreviewProvider {
    static var previews: some View {
        ReactionPicker(picked: { _ in })
    }
}
