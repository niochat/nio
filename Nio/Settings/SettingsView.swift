import SwiftUI

struct SettingsContainerView: View {
    @EnvironmentObject var store: AccountStore
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        SettingsView(accentColor: $settings.accentColor, appIcon: $settings.appIcon, logoutAction: { self.store.logout() })
    }
}

struct SettingsView: View {
    @Binding var accentColor: Color
    @Binding var appIcon: String?
    var logoutAction: () -> Void

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
                        ForEach(AppSettings.alternateIcons) { iconName in
                            HStack {
                                Image("App Icons/\(iconName)")
                                    .resizable()
                                    .frame(width: 60)
                                    .cornerRadius(12)
                                    .padding(5)
                                Text(iconName)
                            }
                            .tag(iconName)
                        }
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
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(accentColor: .constant(.purple), appIcon: .constant(nil), logoutAction: {})
    }
}
