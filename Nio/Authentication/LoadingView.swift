import SwiftUI

struct LoadingView: View {
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
        }
    }
}

struct LoadingView_Previews: PreviewProvider {
    static var previews: some View {
        LoadingView()
    }
}
