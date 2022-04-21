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
    @AppStorage("showAccountsInPicker") var showAccounts: Bool = false

    public var body: some View {
        DisclosureGroup("Accounts", isExpanded: $showAccounts) {
            MenuAccountPickerView()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top)
        }
    }
}

public struct MenuAccountPickerView: View {
    public init() {}

    @EnvironmentObject var store: NioAccountStore

    public var body: some View {
        VStack(alignment: .leading) {
            ForEach(store.accounts.sorted(by: >), id: \.key) { account in
                Button {
                    print("switching account to \(account.value.info.name)")
                    do {
                        try withAnimation { () throws in
                            try store.switchToAccount(account.value.mxID.FQMXID)
                        }
                    } catch {
                        fatalError("Failed to switch to account: \(error.localizedDescription)")
                    }
                    // TODO: switch account
                } label: {
                    MenuAccountPickerAccountView(account: account.value).tag(account.value.mxID.FQMXID)
                }
                .padding(.vertical)
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
    @ObservedObject var account: NioAccount

    var body: some View {
        Label {
            VStack(alignment: .leading) {
                Text(account.displayName ?? account.mxID.FQMXID)
                    .foregroundColor(.gray)
                    .font(.headline)
                if account.displayName != nil {
                    Text(account.mxID.FQMXID)
                        .foregroundColor(.gray)
                        .font(.subheadline)
                }
            }
        } icon: {
            // TODO: avatar
            Image(systemName: "person")
                .foregroundColor(.gray)
                .imageScale(.large)
        }
    }
}

struct MenuAccountPickerView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            MenuAccountPickerView()
                .previewLayout(.fixed(width: 300, height: 200))

            MenuAccountPickerContainerView(showAccounts: true)
                .previewLayout(.fixed(width: 300, height: 200))
                .padding()
        }
        .environmentObject(NioAccountStore.preview)
    }
}
