import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: MatrixStore<AppState, AppAction>

    var body: some View {
        Group {
            if store.state.isLoggedIn {
                ConversationListContainerView()
            } else {
                LoginContainerView()
            }
        }
    }
}
