import SwiftUI

import NioKit

struct SettingsContainerView: View {
    @EnvironmentObject var store: AccountStore
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        SettingsView(accentColor: $settings.accentColor,
                     appIcon: $settings.appIcon,
                     logoutAction: { self.store.logout() })
    }
}

struct SettingsView: View {
    @Binding var accentColor: Color
    @Binding var appIcon: String
    var logoutAction: () -> Void

    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Picker(selection: $accentColor, label: Text(L10n.Settings.accentColor)) {
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

                    Picker(selection: $appIcon, label: Text(L10n.Settings.appIcon)) {
                        ForEach(AppSettings.alternateIcons) { $0 }
                    }
                }

                Section {
                    Button(action: {
                        self.logoutAction()
                    }, label: {
                        Text(L10n.Settings.logOut)
                    })
                }
            }
            .navigationBarTitle(Text(L10n.Settings.title), displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Settings.done) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(accentColor: .constant(.purple),
                     appIcon: .constant("Default"),
                     logoutAction: {})
    }
}
