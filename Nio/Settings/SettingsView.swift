import SwiftUI

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
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(logoutAction: {})
    }
}
