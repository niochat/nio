import SwiftUI

import NioKit

struct RootView: View {
    @EnvironmentObject var store: AccountStore

    var body: some View {
        switch store.loginState {
        case .loggedIn(let userId):
            RecentRoomsContainerView()
                .environment(\.userId, userId)
                // Can this ever be nil? And if so, what happens with the default fallback?
                .environment(\.homeserver, (store.client?.homeserver.flatMap(URL.init)) ?? HomeserverKey.defaultValue)
        case .loggedOut:
            LoginContainerView()

        case .authenticating:
            LoadingView()

        case .failure(let error):
            VStack {
                Spacer()
                Text(error.localizedDescription)
                Spacer()
                Button(action: {
                    self.store.loginState = .loggedOut
                }, label: {
                    Text(L10n.Login.failureBackToLogin)
                }).padding()
            }
        }
    }
}
