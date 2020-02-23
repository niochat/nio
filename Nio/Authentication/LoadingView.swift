import SwiftUI

struct LoadingView: View {
    var loadingMessages = [
        "Reticulating splines...",
        "Discomfrobulating messages...",
        "❤️",
        "There is no spoon."
    ]

    var body: some View {
        VStack {
            Spacer()

            ActivityIndicator()

            Text(self.loadingMessages.randomElement() ?? "Reticulating splines...")
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
