import SwiftUI
import SDWebImageSwiftUI

import NioKit

struct GenericEventView: View {
    @EnvironmentObject var store: AccountStore

    var text: String
    var image: MXURL?
    var imageURL: URL? {
        return store.client?.homeserver
            .flatMap(URL.init(string:))
            .flatMap { image?.contentURL(on: $0) }
    }

    var body: some View {
        HStack(spacing: 4) {
            Spacer()
            if imageURL != nil {
                WebImage(url: imageURL!)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 15, height: 15)
                    .mask(Circle())
            }
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
            GenericEventView(text: "Ping joined", image: .nioIcon)
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
