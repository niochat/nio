import SwiftUI

import NioKit

struct LoadingView: View {
    @EnvironmentObject private var store: AccountStore

    private let loadingEmoji = [
        "🧑‍🎤",
        "🧑‍🏭",
        "🧑‍🔧",
        "🧑‍💻",
    ]

    private let loadingMessages = [
        L10n.Loading._1,
        L10n.Loading._2,
        L10n.Loading._3,
        L10n.Loading._4,
    ]

    private var randomLoadingMessage: String {
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

            Button(action: self.store.logout) {
                Text(L10n.Loading.cancel).font(.callout)
            }
            .padding()
        }
    }
}

struct LoadingView_Previews: PreviewProvider {
    static var previews: some View {
        LoadingView()
    }
}
