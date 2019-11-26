import SwiftUI
import SwiftMatrixSDK

struct LoginContainerView: View {
    @EnvironmentObject var store: MatrixStore<AppState, AppAction>

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
                  loginState: store.state.loginState)
    }

    private func login() {
        let homeserver = self.homeserver.isEmpty ? "https://matrix.org" : self.homeserver
        guard let homeserverURL = URL(string: homeserver) else {
            // TODO: Handle error
            print("Invalid homeserver URL '\(homeserver)'")
            return
        }
        store.send(SideEffect.login(username: username, password: password, homeserver: homeserverURL))
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
    let loginState: LoginState

    var body: some View {
        VStack {
            Spacer()
            LoginTitleView()

            Spacer()
            LoginForm(username: $username, password: $password, homeserver: $homeserver)

            buttons

            Spacer()
        }
        .keyboardObserving()
        .sheet(isPresented: $showingRegisterView) {
            Text("Registering for new accounts is not yet implemented.")
        }
    }

    var buttons: some View {
        VStack {
            Button(action: {
                self.onLogin()
            }, label: {
                Text("Sign in")
                    .font(.system(size: 18))
                    .bold()
            })
            .padding([.top, .bottom], 30)
            .disabled(!isLoginEnabled())

            Button(action: {
                self.showingRegisterView.toggle()
            }, label: {
                Text("Don't have an account yet?").font(.footnote)
            })
        }
    }
}

private struct LoginTitleView: View {
    var body: some View {
        let nio = Text("Nio").foregroundColor(.accentColor)

        return VStack {
            (Text("👋 Welcome to ") + nio + Text("!"))
                .font(.title)
                .bold()
            Text("Sign in to your account to get started.")
        }
    }
}

private struct LoginForm: View {
    @Binding var username: String
    @Binding var password: String
    @Binding var homeserver: String

    var body: some View {
        VStack {
            FormTextField(title: "Username", text: $username)

            FormTextField(title: "Password", text: $password, isSecure: true)

            FormTextField(title: "Homeserver", text: $homeserver)
            Text("Homeserver is optional if you're using matrix.org.")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}

private struct FormTextField: View {
    @Environment(\.colorScheme) var colorScheme

    var title: LocalizedStringKey
    @Binding var text: String

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
                TextField(title, text: $text)
                    .padding()
                    .autocapitalization(.none)
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
                  loginState: .loggedOut)
            .accentColor(.purple)
    }
}
