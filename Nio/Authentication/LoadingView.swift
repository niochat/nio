import SwiftUI

struct LoadingView: View {
    @EnvironmentObject var store: AccountStore

    var loadingMessages = [
        "🧑‍🎤 Reticulating splines",
        "🧑‍🏭 Discomfrobulating messages",
        "🧑‍🔧 Logging in",
        "🧑‍💻 Restoring session"
    ]

    var body: some View {
        VStack {
            Spacer()

            ActivityIndicator()

            Text(self.loadingMessages.randomElement()!)
                .bold()
                .padding(.horizontal)

            Spacer()

            Button(action: {
                self.store.logout()
            }, label: {
                Text("Cancel").font(.callout)
            })
        }
    }
}

struct LoadingView_Previews: PreviewProvider {
    static var previews: some View {
        LoadingView()
    }
}
