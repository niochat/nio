import SwiftUI

struct SettingsContainerView: View {
    @EnvironmentObject var store: AccountStore
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        SettingsView(accentColor: $settings.accentColor, logoutAction: { self.store.logout() })
    }
}

struct SettingsView: View {
    @Binding var accentColor: Color
    var logoutAction: () -> Void

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Picker(selection: $accentColor, label: Text("Accent Color")) {
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
                }

                Section {
                    Button(action: {
                        self.logoutAction()
                    }, label: {
                        Text("Log Out")
                    })
                }
            }
            .navigationBarTitle("Settings", displayMode: .inline)
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(accentColor: .constant(.purple), logoutAction: {})
    }
}
