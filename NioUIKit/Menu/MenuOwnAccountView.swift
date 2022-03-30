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
                HStack {
                    // TODO: if account.avatarURL
                    Image(systemName: "person")
                        .foregroundColor(.gray)
                        .imageScale(.large)
                        .frame(width: 45, height: 45)

                    VStack(alignment: .leading) {
                        Text(account.displayName ?? account.userID ?? "Unknown User")
                            .foregroundColor(.gray)
                            .font(.headline)

                        // Only show handle if not shown above
                        if account.displayName != nil {
                            Text(account.userID ?? "Unknown mxid")
                                .foregroundColor(.gray)
                                .font(.subheadline)
                        }
                    }
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
