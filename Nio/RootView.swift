import SwiftUI

struct RootView: View {
    @EnvironmentObject var mxStore: MatrixStore

    var body: some View {
        if mxStore.isLoggedIn {
            return AnyView(
                Text("Conversations View")
            )
        } else {
            return AnyView(
                LoginView().onLogin { username, password, homeserver in
                    self.mxStore.login(username: username, password: password, homeserver: homeserver)
                }
            )
        }
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
    }
}
