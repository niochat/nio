import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: MatrixStore<AppState, AppAction>

    var body: some View {
        switch store.state.loginState {
        case .loggedIn:
            return AnyView(
                ConversationListContainerView()
            )
        case .loggedOut:
            return AnyView(
                LoginContainerView()
            )
        case .authenticating:
            return AnyView(
                ActivityIndicator()
            )
        case .failure(let error):
            return AnyView(
                VStack {
                    Text(error.localizedDescription)
                    Button(action: {
                        self.store.send(AppAction.loginState(.loggedOut))
                    }, label: {
                        Text("Go to login")
                    })
                }
            )
        }
    }
}
