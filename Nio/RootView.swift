import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: AccountStore

    var body: some View {
        switch store.loginState {
        case .loggedIn(let userId):
            return AnyView(
                RecentRoomsContainerView()
                .environment(\.userId, userId)
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
                        Text("Go to login")
                    })
                }
            )
        }
    }
}
