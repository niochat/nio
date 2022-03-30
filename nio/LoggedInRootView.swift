//
//  LoggedInRootVie.swift
//  Nio
//
//  Created by Finn Behrens on 26.03.22.
//

import MatrixCore
import NioKit
import SwiftUI

struct LoggedInRootView: View {
    @Environment(\.managedObjectContext) var context

    @FetchRequest(sortDescriptors: []) var accounts: FetchedResults<MatrixAccount>

    @EnvironmentObject var store: NioAccountStore

    var body: some View {
        VStack {
            ForEach(Array(store.accounts.keys), id: \.self) { key in
                Button((store.accounts[key]?.displayName ?? store.accounts[key]?.userID.FQMXID) ?? "??") {
                    Task {
                        do {
                            try await store.logout(accountName: key)
                        } catch {
                            print(error)
                        }
                        print("foo")
                    }
                }
            }
            Button("delete", role: .destructive) {
                Task {
                    try? await self.context.perform {
                        let accounts = try self.context.fetch(MatrixAccount.fetchRequest())
                        for account in accounts {
                            self.context.delete(account)
                        }
                        try self.context.save()
                    }
                }
            }
        }
    }
}

struct LoggedInRootView_Previews: PreviewProvider {
    static var previews: some View {
        LoggedInRootView()
    }
}
