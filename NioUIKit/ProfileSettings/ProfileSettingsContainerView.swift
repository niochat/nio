//
//  ProfileSettingsContainerView.swift
//  NioUIKit_iOS
//
//  Created by Finn Behrens on 30.03.22.
//

import MatrixClient
import MatrixCore
import NioKit
import SwiftUI

struct ProfileSettingsContainerView: View {
    @ObservedObject var account: MatrixAccount
    @EnvironmentObject var store: NioAccountStore

    @Environment(\.managedObjectContext) var moc
    @Environment(\.dismiss) private var dismiss

    @State var capabilities = MatrixCapabilities()

    @State var task: Task<Void, Never>?

    var body: some View {
        List {
            Section(header: Text("USER SETTINGS")) {
                // TODO: Profile Picture

                // Display Name
                HStack {
                    Text("Display Name")
                    Spacer(minLength: 20)

                    TextField("Display Name", text: $account.wrappedDisplayName)
                        .multilineTextAlignment(.trailing)
                        .disabled(!self.capabilities.capabilities.canSetDisplayName)
                }

                // Password
                Button("Change password", role: .destructive) {
                    print("TODO: implement change password")
                }
                .disabled(!self.capabilities.capabilities.canChangePassword)
            }

            Section(header: Text("SECURITY")) {
                NavigationLink("Security") {
                    ProfileSettingsSecurityContainerView()
                        .environmentObject(account)
                }
            }

            ProfileSettingsDangerZone()
        }
        .environmentObject(account)
        .navigationTitle(account.displayName ?? account.userID ?? "Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem {
                Button(action: {
                    print("saving...")
                    Task(priority: .userInitiated) {
                        let changes = account.changedValues()

                        let nioAccount = store.accounts[account.userID!]!

                        if let displayName = changes["displayName"] as? String {
                            NioAccountStore.logger.debug("Changing displayName to \(displayName)")

                            do {
                                try await nioAccount.matrixCore.client.setDisplayName(displayName, userID: account.userID!)
                            } catch {
                                NioAccountStore.logger.fault("Failed to save displayName to matrix account")
                            }
                        }
                        do {
                            try moc.save()
                        } catch {
                            NioAccountStore.logger.fault("Failed to save changed account to CoreData")
                        }

                        // TODO: save to CoreData
                        self.moc.undoManager = nil
                        self.dismiss()
                    }
                }) {
                    Text("Save")
                }
                .disabled(!account.hasChanges)
            }
        }
        .onAppear {
            self.moc.undoManager = UndoManager()
            self.probeServer()
        }
        .onDisappear {
            self.task?.cancel()
            print("discarding")
            self.moc.undoManager?.undo()
            self.moc.undoManager = nil
        }
    }

    private func probeServer() {
        task = Task(priority: .high) {
            let nioAccount = store.accounts[account.userID!]

            do {
                let capabilities = try await nioAccount?.matrixCore.client.getCapabilities()
                if let capabilities = capabilities {
                    self.capabilities = capabilities
                }
            } catch {
                NioAccountStore.logger.fault("Failed to get server capabilities")
            }
        }
    }
}

struct ProfileSettingsDangerZone: View {
    @EnvironmentObject var account: MatrixAccount
    @EnvironmentObject var store: NioAccountStore

    @Environment(\.dismiss) private var dismiss

    @State private var showSignOutDialog: Bool = false
    @State private var showDeactivateDialog: Bool = false

    var body: some View {
        Section(header: Text("DANGER ZONE")) {
            Button("Sign Out") {
                showSignOutDialog = true
            }
            .disabled(showSignOutDialog)
            .confirmationDialog("Are you sure you want to sign out?", isPresented: $showSignOutDialog, titleVisibility: .visible) {
                Button("Sign out", role: .destructive) {
                    print("TODO: implement sign out")
                    Task(priority: .userInitiated) {
                        do {
                            try await self.store.logout(accountName: account.userID!)
                        } catch {
                            NioAccountStore.logger.fault("Failed to log out: \(error.localizedDescription)")
                        }
                    }
                    // TODO:
                }
            }

            Button("Deactivate my account", role: .destructive) {
                showDeactivateDialog = true
            }
            .disabled(showDeactivateDialog)
            .confirmationDialog("Are you sure you want to disable your account? This cannot be undone", isPresented: $showDeactivateDialog, titleVisibility: .visible) {
                Text("This cannot be undone")
                    .font(.headline)
                    .foregroundColor(.red)
                Button("Deactivate", role: .destructive) {
                    print("TODO: deactivate account")
                    // TODO:
                }
            }
        }
    }
}

struct ProfileSettingsContainerView_Previews: PreviewProvider {
    static let account: MatrixAccount = MatrixStore.createAmir(context: MatrixStore.preview.viewContext)

    static var previews: some View {
        Group {
            NavigationView {
                ProfileSettingsContainerView(account: ProfileSettingsContainerView_Previews.account)
            }
        }
    }
}
