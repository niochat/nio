//
//  ProfileSettingsContainerView.swift
//  NioUIKit_iOS
//
//  Created by Finn Behrens on 30.03.22.
//

import MatrixCore
import SwiftUI

struct ProfileSettingsContainerView: View {
    @ObservedObject var account: MatrixAccount

    @Environment(\.dismiss) private var dismiss

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
                }

                // Password
                Button("Change password", role: .destructive) {
                    print("TODO: implement change password")
                }
            }

            Section(header: Text("SECURITY")) {
                NavigationLink("Security") {
                    VStack {
                        Text("Device id's and fun")
                    }
                    .navigationTitle("Security")
                }
            }

            ProfileSettingsDangerZone(account: account)
        }
        .navigationTitle(account.displayName ?? account.userID ?? "Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem {
                Button(action: {
                    print("saving...")
                    // TODO: save to CoreData
                    dismiss()
                }) {
                    Text("Save")
                }
                .disabled(!account.hasChanges)
            }
        }
        .onDisappear {
            print("discarding")
        }
    }
}

struct ProfileSettingsDangerZone: View {
    @ObservedObject var account: MatrixAccount

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
