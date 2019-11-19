import SwiftUI

struct LoginView: View {
    @State private var username = ""
    @State private var password = ""
    @State private var homeserver = "matrix.org"

    @State private var showingRegisterView = false

    var loginHandler: ((String, String, URL) -> Void)?

    func onLogin(handler: @escaping (String, String, URL) -> Void) -> LoginView {
        var copy = self
        copy.loginHandler = handler
        return copy
    }

    var body: some View {
        VStack {
            Spacer()
            LoginTitleView()

            Spacer()
            LoginForm(username: $username, password: $password, homeserver: $homeserver)

            Button(action: {
                // TODO: Validate HS URL (and non-empty username/pw) and disable login button if invalid
                self.loginHandler?(self.username, self.password, URL(string: "https://matrix.org")!)
            }, label: {
                Text("Log in").bold()
            }).padding([.top, .bottom], 30)

            Button(action: {
                self.showingRegisterView.toggle()
            }, label: {
                Text("Register a new account on matrix.org").font(.footnote)
            })

            Spacer()
        }
        .sheet(isPresented: $showingRegisterView) {
            Text("Registering for new accounts not yet implemented.")
        }
    }
}

private struct LoginTitleView: View {
    var body: some View {
        let purpleTitle = Text("Nio").foregroundColor(.purple)

        return VStack {
            (Text("👋 Welcome to ") + purpleTitle + Text("!"))
                .font(.title)
                .bold()
            Text("Log in to your account below to get started.")
        }
    }
}

private struct LoginForm: View {
    @Binding var username: String
    @Binding var password: String
    @Binding var homeserver: String

    @ObservedObject private var keyboard = KeyboardGuardian(textFieldCount: 1)

    var body: some View {
        VStack {
            HStack(alignment: .center) {
                Text("Username")
                    .font(Font.body.smallCaps())
                    .foregroundColor(.purple)
                TextField("t.anderson", text: $username)
            }
            .padding([.horizontal, .bottom])

            HStack(alignment: .center) {
                Text("Password")
                    .font(Font.body.smallCaps())
                    .foregroundColor(.purple)
                SecureField("********", text: $password)
            }
            .padding([.horizontal, .bottom])

            HStack(alignment: .center) {
                Text("Homeserver")
                    .font(Font.body.smallCaps())
                    .foregroundColor(.purple)
                TextField("matrix.org", text: $homeserver,
                          onEditingChanged: { if $0 { self.keyboard.showField = 0 }})
                    .background(GeometryGetter(rect: $keyboard.rects[0]))
                    .keyboardType(.URL)
            }
            .padding(.horizontal)
        }
        .offset(y: keyboard.slide).animation(.easeInOut(duration: 0.25))
        .onAppear { self.keyboard.addObserver() }
        .onDisappear { self.keyboard.removeObserver() }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
