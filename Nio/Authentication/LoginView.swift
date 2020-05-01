import SwiftUI
import SwiftMatrixSDK

struct LoginContainerView: View {
    @EnvironmentObject var store: AccountStore
    @EnvironmentObject var settings: AppSettings

    @State private var username = ""
    @State private var password = ""
    @State private var homeserver = ""

    @State private var showingRegisterView = false

    var body: some View {
        LoginView(username: $username,
                  password: $password,
                  homeserver: $homeserver,
                  showingRegisterView: $showingRegisterView,
                  isLoginEnabled: isLoginEnabled,
                  onLogin: login,
                  guessHomeserverURL: guessHomeserverURL)
        .sheet(isPresented: $showingRegisterView) {
            RegistrationContainerView()
                .accentColor(self.settings.accentColor)
                .environmentObject(self.store)
        }
    }

    private func login() {
        let homeserver = self.homeserver.isEmpty ? "https://matrix.org" : self.homeserver
        guard let homeserverURL = URL(homeserverString: homeserver) else {
            // TODO: Handle error
            print("Invalid homeserver URL '\(homeserver)'")
            return
        }

        store.login(username: username, password: password, homeserver: homeserverURL)
    }
    
    private func guessHomeserverURL() {
        if !username.isEmpty && homeserver.isEmpty {
            let userparts = username.components(separatedBy: ":")
            guard userparts.count == 2 else { return }
            let mxautodiscovery = MXAutoDiscovery(domain: userparts[1])
            mxautodiscovery?.findClientConfig({ config in
                // Check again to prevent race condition.
                if self.homeserver.isEmpty {
                    if let wellKnown = config.wellKnown {
                        self.homeserver = wellKnown.homeServer.baseUrl
                    }
                }
            }, failure: {_ in })
        }
    }

    private func isLoginEnabled() -> Bool {
        guard !username.isEmpty && !password.isEmpty else { return false }
        let homeserver = self.homeserver.isEmpty ? "https://matrix.org" : self.homeserver
        guard URL(string: homeserver) != nil else { return false }
        return true
    }
}

struct LoginView: View {
    @Binding var username: String
    @Binding var password: String
    @Binding var homeserver: String

    @Binding var showingRegisterView: Bool

    let isLoginEnabled: () -> Bool
    let onLogin: () -> Void
    let guessHomeserverURL: () -> Void

    var body: some View {
        VStack {
            Spacer()
            LoginTitleView()

            Spacer()
            LoginForm(username: $username, password: $password, homeserver: $homeserver, guessHomeserverURL: guessHomeserverURL)

            buttons

            Spacer()
        }
        .keyboardObserving()
    }

    var buttons: some View {
        VStack {
            Button(action: {
                self.onLogin()
            }, label: {
                Text(L10n.Login.signIn)
                    .font(.system(size: 18))
                    .bold()
            })
            .padding([.top, .bottom], 30)
            .disabled(!isLoginEnabled())

            Button(action: {
                self.showingRegisterView.toggle()
            }, label: {
                Text(L10n.Login.openRegistrationPrompt).font(.footnote)
            })
        }
    }
}

struct LoginTitleView: View {
    var body: some View {
        let nio = Text("Nio").foregroundColor(.accentColor)

        return VStack {
            // FIXME: This probably breaks localisation.
            (Text(L10n.Login.welcomeHeader) + nio + Text("!"))
                .font(.title)
                .bold()
            Text(L10n.Login.welcomeMessage)
        }
    }
}

struct LoginForm: View {
    @Binding var username: String
    @Binding var password: String
    @Binding var homeserver: String

    let guessHomeserverURL: () -> Void

    var body: some View {
        VStack {
            LoginFormTextField(placeholder: L10n.Login.Form.username,
                               text: $username,
                               onEditingChanged: { _ in self.guessHomeserverURL() })

            LoginFormTextField(placeholder: L10n.Login.Form.password,
                               text: $password,
                               isSecure: true)

            LoginFormTextField(placeholder: L10n.Login.Form.homeserver,
                               text: $homeserver)

            Text(L10n.Login.Form.homeserverOptionalExplanation)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.horizontal)
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView(username: .constant(""),
                  password: .constant(""),
                  homeserver: .constant(""),
                  showingRegisterView: .constant(false),
                  isLoginEnabled: { return false },
                  onLogin: {},
                  guessHomeserverURL: {})
            .accentColor(.purple)
    }
}
