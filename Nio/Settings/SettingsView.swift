import SwiftUI
import MatrixSDK

import NioKit

struct SettingsContainerView: View {
    @EnvironmentObject var store: AccountStore

    var body: some View {
        SettingsView(logoutAction: { self.store.logout() })
    }
}

struct SettingsView: View {
    @AppStorage("accentColor") private var accentColor: Color = .purple
    @StateObject private var appIconTitle = AppIconTitle()
    let logoutAction: () -> Void
    @AppStorage("identityServerBool") private var identityServerBool: Bool = false
    @AppStorage("identityServer") private var identityServer: String = "https://vector.im"
    @AppStorage("syncContacts") private var syncContacts: Bool = false
    @EnvironmentObject var store: AccountStore

    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Picker(selection: $accentColor, label: Text(verbatim: L10n.Settings.accentColor)) {
                        ForEach(Color.allAccentOptions, id: \.self) { color in
                            HStack {
                                Circle()
                                    .frame(width: 20)
                                    .foregroundColor(color)
                                Text(color.description.capitalized)
                            }
                            .tag(color)
                        }
                    }

                    Picker(selection: $appIconTitle.current, label: Text(verbatim: L10n.Settings.appIcon)) {
                        ForEach(AppIconTitle.alternatives) { AppIcon(title: $0) }
                    }
                }

                Section {
                    Toggle("Enable Identity Server", isOn: $identityServerBool).onChange(of: identityServerBool, perform: syncIdentityServer(isSync:))
                    if identityServerBool {
                        TextField("Identity URL", text: $identityServer)
                        Toggle("Sync Contacts", isOn: $syncContacts).onChange(of: syncContacts, perform: syncContacts(isSync:))
                    }
                }

                Section {
                    Button(action: {
                        self.logoutAction()
                    }, label: {
                        Text(verbatim: L10n.Settings.logOut)
                    })
                }
            }
            .navigationBarTitle(L10n.Settings.title, displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Settings.dismiss) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private func syncIdentityServer(isSync: Bool) {
        if isSync {
            store.setIdentityService()
        } else {
            // Revoke Contact Sync
            syncContacts = false
        }
    }
    
    private func syncContacts(isSync: Bool) {
        if isSync {
            let contacts = Contacts.getAllContacts()
            contacts.forEach { (contact) in
                var mx3pids: [MX3PID] = []
                contact.emailAddresses.forEach { (email) in
                    mx3pids.append(MX3PID.init(medium: MX3PID.Medium.email, address: email.value as String))
                }
                store.identityService?.lookup3PIDs(mx3pids) { response in
                    response.value?.forEach({ (responseItem: (key: MX3PID, value: String)) in
                        print(contact.givenName + " " + responseItem.value)
                    })
                }
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(logoutAction: {})
    }
}
