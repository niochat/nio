import SwiftUI

struct GenericEventView: View {
    var text: String

    var body: some View {
        HStack {
            Spacer()
            Text(text)
                .font(.caption)
                .foregroundColor(.gray)
            Spacer()
        }
        .padding(.vertical, 3)
    }
}

struct GenericEventView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            GenericEventView(text: "Ping joined")
            GenericEventView(text: "Ping changed the topic to '🐧'")

            VStack(spacing: 0) {
                GenericEventView(text: "Ping joined")
                GenericEventView(text: "Ping joined")
                GenericEventView(text: "Ping joined")
            }
        }
        .accentColor(.purple)
//        .environment(\.colorScheme, .dark)
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
