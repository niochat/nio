import SwiftUI

struct RegistrationContainerView: View {
    @EnvironmentObject var store: AccountStore

    @State private var username = ""
    @State private var password = ""
    @State private var passwordConfirmation = ""
    @State private var homeserver = ""

    private func register() {
        let homeserver = self.homeserver.isEmpty ? "https://matrix.org" : self.homeserver
        guard let homeserverURL = URL(homeserverString: homeserver) else {
            // TODO: Handle error
            print("Invalid homeserver URL '\(homeserver)'")
            return
        }
        store.register(username: username, password: password, homeserver: homeserverURL)
    }

    var body: some View {
        RegistrationView(username: $username,
                         password: $password,
                         passwordConfirmation: $passwordConfirmation,
                         homeserver: $homeserver,
                         onRegister: register,
                         isRegistrationEnabled: isRegistrationEnabled)
    }

    private func isRegistrationEnabled() -> Bool {
        guard !username.isEmpty && !password.isEmpty else { return false }
        guard password == passwordConfirmation else { return false }
        let homeserver = self.homeserver.isEmpty ? "https://matrix.org" : self.homeserver
        guard URL(string: homeserver) != nil else { return false }
        return true
    }
}

struct RegistrationView: View {
    @Binding var username: String
    @Binding var password: String
    @Binding var passwordConfirmation: String
    @Binding var homeserver: String

    var onRegister: () -> Void
    var isRegistrationEnabled: () -> Bool

    static var randomServerSuggestions = [
        "https://feneas.org",
        "https://allmende.io",
        "https://tchncs.de",
        "https://fairydust.space",
    ]

    var header: some View {
        VStack {
            Image(systemName: "person.3.fill")
                .font(.title)
                .foregroundColor(.accentColor)
            Text(L10n.Registration.header)
                .font(.headline)
        }
        .padding(.bottom)
    }

    var mxidPreview: String? {
        // TODO: This should ideally also try a well-known discovery like the login does.
        switch (username, homeserver) {
        case ("", _):
            return nil
        case (var user, ""):
            user = user.replacingOccurrences(of: "@", with: "")
            return "@\(user):matrix.org"
        case (var user, var server):
            user = user.replacingOccurrences(of: "@", with: "")
            server = server.replacingOccurrences(of: "https://", with: "")
            return "@\(user):\(server)"
        }
    }

    var form: some View {
        VStack {
            LoginFormTextField(placeholder: L10n.Login.Form.username, text: $username)
                .padding(.horizontal)
                .padding(.bottom)

            LoginFormTextField(placeholder: L10n.Login.Form.password,
                               text: $password,
                               isSecure: true)
                .padding(.horizontal)

            LoginFormTextField(placeholder: L10n.Registration.confirmPassword,
                               text: $passwordConfirmation,
                               isSecure: true)
                .padding(.horizontal)
                .padding(.bottom)

            LoginFormTextField(placeholder: L10n.Login.Form.homeserver,
                               text: $homeserver,
                               buttonIcon: "shuffle",
                               buttonAction: { self.homeserver = Self.randomServerSuggestions.randomElement()! })
                .padding(.horizontal)
        }
    }

    var body: some View {
        VStack {
            Spacer()
            header

            Spacer()
            Text(L10n.Registration.explanation)
                .font(.callout)
                .padding(.horizontal)
            Spacer()

            form

            Text(L10n.Registration.homeserverExplanation)
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.horizontal)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: {
                self.onRegister()
            }, label: {
                VStack {
                    Text(L10n.Registration.register)
                        .font(.system(size: 18))
                        .bold()
                    if mxidPreview != nil {
                        Text(mxidPreview!)
                            .font(.caption)
                            .bold()
                    }
                }

            })
            .padding([.top, .bottom], 30)
            .disabled(!isRegistrationEnabled())

            Spacer()
        }
        .keyboardObserving()
    }
}

struct RegistrationView_Previews: PreviewProvider {
    static var previews: some View {
        RegistrationView(username: .constant(""),
                         password: .constant(""),
                         passwordConfirmation: .constant(""),
                         homeserver: .constant(""),
                         onRegister: { },
                         isRegistrationEnabled: { true })
            .accentColor(.purple)
    }
}
