import SwiftUI

import NioKit

struct LoadingView: View {
    @EnvironmentObject var store: AccountStore

    var loadingEmoji = [
        "🧑‍🎤",
        "🧑‍🏭",
        "🧑‍🔧",
        "🧑‍💻",
    ]

    var loadingMessages = [
        L10n.Loading._1,
        L10n.Loading._2,
        L10n.Loading._3,
        L10n.Loading._4,
    ]

    var randomLoadingMessage: String {
        "\(loadingEmoji.randomElement()!) \(loadingMessages.randomElement()!)"
    }

    var body: some View {
        VStack {
            Spacer()

            ProgressView().padding(1)

            Text(self.randomLoadingMessage)
                .bold()
                .padding(.horizontal)

            Spacer()

            Button(action: {
                self.store.logout()
            }, label: {
                Text(L10n.Loading.cancel).font(.callout)
            }).padding()
        }
    }
}

struct LoadingView_Previews: PreviewProvider {
    static var previews: some View {
        LoadingView()
    }
}
