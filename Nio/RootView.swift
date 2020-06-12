import SwiftUI

import NioKit

struct RootView: View {
    @EnvironmentObject var store: AccountStore

    var body: some View {
        switch store.loginState {
        case .loggedIn(let userId):
            return AnyView(
                RecentRoomsContainerView()
                    .environment(\.userId, userId)
                    // Can this ever be nil? And if so, what happens with the default fallback?
                    .environment(\.homeserver, (store.client?.homeserver.flatMap(URL.init)) ?? HomeserverKey.defaultValue)
            )
        case .loggedOut:
            return AnyView(
                LoginContainerView()
            )
        case .authenticating:
            return AnyView(
                LoadingView()
            )
        case .failure(let error):
            return AnyView(
                VStack {
                    Text(error.localizedDescription)
                    Button(action: {
                        self.store.loginState = .loggedOut
                    }, label: {
                        Text(L10n.Login.failureBackToLogin)
                    })
                }
            )
        }
    }
}
