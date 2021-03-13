import SwiftUI
import MatrixSDK

import NioKit

struct LoginContainerView: View {
    @EnvironmentObject var store: AccountStore

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
    }

    private func login() {
        var homeserver = self.homeserver.isEmpty ? "https://matrix.org" : self.homeserver

        // If there's no scheme at all, the URLComponents initializer below will think it's a path with no hostname.
        if !homeserver.contains("//") {
            homeserver = "https://\(homeserver)"
        }
        var homeserverURLComponents = URLComponents(string: homeserver)
        homeserverURLComponents?.scheme = "https"
        guard let homeserverURL = homeserverURLComponents?.url else {
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
        .sheet(isPresented: $showingRegisterView) {
            Link(L10n.Login.registerNotYetImplemented, destination: URL(string: "https://app.element.io/#/register")!)
        }
    }

    private var buttons: some View {
        VStack {
            Button(action: {
                self.onLogin()
            }, label: {
                Text(verbatim: L10n.Login.signIn)
                    .font(.system(size: 18))
                    .bold()
            })
            .padding([.top, .bottom], 30)
            .disabled(!isLoginEnabled())

            Button(action: {
                self.showingRegisterView.toggle()
            }, label: {
                Text(verbatim: L10n.Login.openRegistrationPrompt).font(.footnote)
            })
        }
    }
}

struct LoginTitleView: View {
    var body: some View {
        let nio = Text("Nio").foregroundColor(.accentColor)

        return VStack {
            (Text("👋") + Text(verbatim: L10n.Login.welcomeHeader) + nio + Text("!"))
                .font(.title)
                .bold()
            Text(verbatim: L10n.Login.welcomeMessage)
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
            FormTextField(title: L10n.Login.Form.username, text: $username, onEditingChanged: { _ in
                self.guessHomeserverURL()
            })

            FormTextField(title: L10n.Login.Form.password, text: $password, isSecure: true)

          #if os(macOS)
            FormTextField(title: L10n.Login.Form.homeserver, text: $homeserver)
          #else
            FormTextField(title: L10n.Login.Form.homeserver, text: $homeserver, keyboardType: .URL)
          #endif
            Text(verbatim: L10n.Login.Form.homeserverOptionalExplanation)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}

private struct FormTextField: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    @Binding var text: String
    var onEditingChanged: ((Bool) -> Void)?

  #if os(macOS)
  #else
    var keyboardType: UIKeyboardType = .default
  #endif

    var isSecure = false

    var body: some View {
        ZStack {
            Capsule(style: .continuous)
                .foregroundColor(colorScheme == .light ? Color(#colorLiteral(red: 0.9395676295, green: 0.9395676295, blue: 0.9395676295, alpha: 1)) : Color(#colorLiteral(red: 0.2293992357, green: 0.2293992357, blue: 0.2293992357, alpha: 1)))
                .frame(height: 50)
            if isSecure {
                SecureField(title, text: $text)
                    .padding()
                    .textContentType(.password)
            } else {
              #if os(macOS)
                TextField(title, text: $text, onEditingChanged: onEditingChanged ?? { _ in })
                    .padding()
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
              #else
                TextField(title, text: $text, onEditingChanged: onEditingChanged ?? { _ in })
                    .padding()
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .keyboardType(keyboardType)
              #endif
            }
        }
        .padding(.horizontal)
        .frame(maxWidth: 400)
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
