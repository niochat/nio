import SwiftUI

struct LoadingView: View {
    @EnvironmentObject var store: AccountStore

    var loadingMessages = [
        L10n.Loading._1,
        L10n.Loading._2,
        L10n.Loading._3,
        L10n.Loading._4,
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
                Text(L10n.Loading.cancel).font(.callout)
            })
        }
    }
}

struct LoadingView_Previews: PreviewProvider {
    static var previews: some View {
        LoadingView()
    }
}
