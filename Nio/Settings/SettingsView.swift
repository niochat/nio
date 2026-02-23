import SwiftUI
import MatrixSDK
import NioKit

struct SettingsContainerView: View {
    @EnvironmentObject var store: AccountStore

    var body: some View {
      #if os(macOS)
        MacSettingsView(logoutAction: self.store.logout)
      #else
        SettingsView(logoutAction: self.store.logout)
      #endif
    }
}

private struct MacSettingsView: View {
    @AppStorage("accentColor") private var accentColor: Color = .purple
    let logoutAction: () -> Void

    var body: some View {
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
                // No icon picker on macOS
            }

            Section {
                Button(action: self.logoutAction) {
                    Text(verbatim: L10n.Settings.logOut)
                }
            }
        }
        .padding()
        .frame(maxWidth: 320)
    }
}

private struct SettingsView: View {
    @AppStorage("accentColor") private var accentColor: Color = .purple
    @StateObject private var appIconTitle = AppIconTitle()
    let logoutAction: () -> Void
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

                IdentityServerSettingsContainerView()

                Section {
                    Button(action: self.logoutAction) {
                       Text(verbatim: L10n.Settings.logOut)
                    }
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
