//
//  MenuAccountPickerView.swift
//  Nio
//
//  Created by Finn Behrens on 30.03.22.
//

import MatrixCore
import NioKit
import SwiftUI

public struct MenuAccountPickerContainerView: View {
    @Binding var currentAccount: String

    @AppStorage("showAccountsInPicker") var showAccounts: Bool = false

    public var body: some View {
        VStack(alignment: .leading) {
            Button(action: {
                showAccounts.toggle()
            }) {
                Image(systemName: "greaterthan")
                    .foregroundColor(.gray)
                    .imageScale(.medium)
                    .rotationEffect(showAccounts ? .degrees(90) : .zero)
            }.padding(.bottom)

            if showAccounts {
                MenuAccountPickerView(currentAccount: $currentAccount)
                    .padding(.leading)
            }
        }
    }
}

public struct MenuAccountPickerView: View {
    @Binding var currentAccount: String

    @FetchRequest(sortDescriptors: []) var accounts: FetchedResults<MatrixAccount>

    init(currentAccount: Binding<String>) {
        _currentAccount = currentAccount

        _accounts = FetchRequest<MatrixAccount>(sortDescriptors: [NSSortDescriptor(key: "userID", ascending: true)], predicate: NSPredicate(format: "userID != %@", currentAccount.wrappedValue))
    }

    public var body: some View {
        VStack(alignment: .leading) {
            ForEach(accounts, id: \.userID) { account in
                Button(action: {
                    print("switching account to \(account.userID ?? "Unknown user")")
                    currentAccount = account.userID ?? ""
                }) {
                    MenuAccountPickerAccountView(account: account).tag(account.userID ?? "Unknown user")
                }.padding(.vertical)
            }

            Button(action: {
                // TODO: implement add account screen
                NioAccountStore.logger.fault("Not yet implemented: Add account")
            }) {
                HStack {
                    Image(systemName: "plus")
                        .foregroundColor(.gray)
                        .imageScale(.large)
                    Text("Add Account")
                        .foregroundColor(.gray)
                        .font(.body)
                }
            }
        }
    }
}

struct MenuAccountPickerAccountView: View {
    let account: MatrixAccount

    var body: some View {
        HStack {
            // TODO: if account.avatarURL
            Image(systemName: "person")
                .foregroundColor(.gray)
                .imageScale(.large)
            VStack(alignment: .leading) {
                Text(account.displayName ?? account.userID ?? "Unknown user")
                    .foregroundColor(.gray)
                    .font(.headline)
                if account.displayName != nil {
                    Text(account.userID ?? "Unknown mxid")
                        .foregroundColor(.gray)
                        .font(.subheadline)
                }
            }
        }
    }
}

struct MenuAccountPickerView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            MenuAccountPickerView(currentAccount: .constant("@amir_sanders:example.com"))
                .previewLayout(.fixed(width: 300, height: 200))

            MenuAccountPickerContainerView(currentAccount: .constant("@amir_sanders:example.com"), showAccounts: true)
                .previewLayout(.fixed(width: 300, height: 200))
        }
        .environment(\.managedObjectContext, MatrixStore.preview.viewContext)
    }
}
