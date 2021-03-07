import SwiftUI

import NioKit

struct RootView: View {
    @EnvironmentObject private var store: AccountStore
  
    private var homeserverURL: URL {
        // Can this ever be nil? And if so, what happens with the default fallback?
        assert(store.client != nil)
        let configuredURL = store.client?.homeserver.flatMap(URL.init)
        assert(configuredURL != nil)
        return configuredURL ?? HomeserverKey.defaultValue
    }

    var body: some View {
        switch store.loginState {
        case .loggedIn(let userId):
            RecentRoomsContainerView()
                .environment(\.userId, userId)
                .environment(\.homeserver, homeserverURL)
          
        case .loggedOut:
            LoginContainerView()

        case .authenticating:
            LoadingView()

        case .failure(let error):
            VStack {
                Spacer()
                Text(error.localizedDescription)
                Spacer()
                Button(action: { self.store.loginState = .loggedOut }) {
                    Text(L10n.Login.failureBackToLogin)
                }
                .padding()
            }
        }
    }
}
