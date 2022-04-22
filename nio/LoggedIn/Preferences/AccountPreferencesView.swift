//
//  AccountPreferencesView.swift
//  Nio
//
//  Created by Finn Behrens on 21.04.22.
//

import MatrixClient
import NioKit
import SwiftUI

struct AccountPreferencesView: View {
    @EnvironmentObject var account: NioAccount
    @EnvironmentObject var deepLinker: DeepLinker
    @Environment(\.dismiss) private var dismiss

    @State private var working = false
    @State private var newAccountName: String = ""

    var body: some View {
        List {
            Section {
                // Profile name
                HStack {
                    Text("Account Name")
                    Spacer(minLength: 10)

                    TextField("Account Name", text: $newAccountName)
                        .multilineTextAlignment(.trailing)
                }

                Button("foo") {
                    deepLinker.mainSelection = .home(MatrixFullUserIdentifier(localpart: "bob", domain: "example.com"))
                }
            } header: {
                Text("USER SETTINGS")
            }
        }
        .navigationTitle(account.info.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if working {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Button("Save", action: self.save)
                        // TODO: some way to see if there is something to save
                        .disabled(false)
                }
            }
        }
        .onAppear {
            self.newAccountName = account.info.name
        }
    }

    private func save() {
        working = true
        Task(priority: .userInitiated) {
            print("save")
            do {
                try await self.saveAccountName()

                DispatchQueue.main.async {
                    self.working = false
                    self.dismiss()
                }
            } catch {
                NioAccountStore.logger
                    .warning("Failed to save user config for user \(self.account.info.name) (\(self.account.mxID)")
                working = false
            }
        }
    }

    private func saveAccountName() async throws {
        if account.info.name != newAccountName {
            NioAccountStore.logger.debug("Saving account name")
            account.info.name = newAccountName
            try await account.updateInfo()
        }
    }
}

struct AccountPreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        AccountPreferencesView()
    }
}
