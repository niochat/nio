import SwiftUI

struct ReactionPicker: View {
    let emoji = ["👍", "👎", "😄", "🎉", "❤️", "🚀", "👀"]

    var picked: (String) -> Void

    var body: some View {
        VStack {
            Text("Tap on an emoji to send that reaction.")
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
