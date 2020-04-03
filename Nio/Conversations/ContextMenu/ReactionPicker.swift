import SwiftUI

struct ReactionPicker: View {
    let emoji = ["👍", "👎", "😄", "🎉", "❤️", "🚀", "👀"]

    var picked: (String) -> Void

    var body: some View {
        HStack {
            ForEach(emoji, id: \.self) { emoji in
                Button(action: { self.picked(emoji) },
                       label: { Text(emoji) })
            }
        }
    }
}

struct ReactionPicker_Previews: PreviewProvider {
    static var previews: some View {
        ReactionPicker(picked: { _ in })
    }
}
