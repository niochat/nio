//
//  MenuOwnAccountView.swift
//  NioUIKit_iOS
//
//  Created by Finn Behrens on 30.03.22.
//

import MatrixCore
import SwiftUI

struct MenuOwnAccountContainerView: View {
    let currentAccount: String

    var body: some View {
        MenuOwnAccountView(currentAccount: currentAccount)
    }
}

struct MenuOwnAccountView: View {
    let currentAccount: String

    @FetchRequest(sortDescriptors: []) var accounts: FetchedResults<MatrixAccount>

    init(currentAccount: String) {
        self.currentAccount = currentAccount

        _accounts = FetchRequest<MatrixAccount>(sortDescriptors: [NSSortDescriptor(key: "userID", ascending: true)], predicate: NSPredicate(format: "userID == %@", currentAccount))
    }

    var body: some View {
        VStack(alignment: .leading) {
            ForEach(accounts, id: \.userID) { account in
                NavigationLink(destination: {
                    ProfileSettingsContainerView(account: account)
                }) {
                    MenuAccountPickerAccountView(account: account)
                }
            }
            // TODO: add a banner if no accounts are returned, because of an Invalid currentAccount?
        }
    }
}

struct MenuOwnAccountView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            MenuOwnAccountView(currentAccount: "@amir_sanders:example.com")
                .environment(\.managedObjectContext, MatrixStore.preview.viewContext)
                .previewLayout(.fixed(width: 300, height: 60))
        }
    }
}
