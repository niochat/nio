//
//  AccountPreferencesView.swift
//  Nio
//
//  Created by Finn Behrens on 21.04.22.
//

import SwiftUI
import NioKit

struct AccountPreferencesView: View {
    @EnvironmentObject var account: NioAccount
    @Environment(\.dismiss) private var dismiss

    @State private var working = false
    @State private var newAccountName: String = ""

    var body: some View {
        List{
            Section {
                // Profile name
                HStack {
                    Text("Account Name")
                    Spacer(minLength: 10)

                    TextField("Account Name", text: $newAccountName)
                        .multilineTextAlignment(.trailing)
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
        self.working = true
        Task(priority: .userInitiated) {
            print("save")
            do {
                try await self.saveAccountName()

                DispatchQueue.main.async {
                    self.working = false
                    self.dismiss()
                }
            } catch {
                NioAccountStore.logger.warning("Failed to save user config for user \(self.account.info.name) (\(self.account.mxID)")
                working = false
            }
        }
    }

    private func saveAccountName() async throws {
        if self.account.info.name != newAccountName {
            NioAccountStore.logger.debug("Saving account name")
            self.account.info.name = newAccountName
            try await account.updateInfo()
        }
    }
}

struct AccountPreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        AccountPreferencesView()
    }
}
