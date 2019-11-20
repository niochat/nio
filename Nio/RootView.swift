import SwiftUI

struct RootView: View {
    @EnvironmentObject var mxStore: MatrixStore

    var body: some View {
        Group {
            if mxStore.isLoggedIn {
                ConversationListView()
            } else {
                LoginView()
            }
        }
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
            .environmentObject(MatrixStore())
    }
}
