import SwiftUI
import NioKit

struct SettingsContainerView: View {
    @EnvironmentObject var store: AccountStore

    @MainActor
    var body: some View {
      #if os(macOS)
        MacSettingsView(logoutAction: {
            Task.init(priority: .userInitiated) {
                await self.store.logout()
            }
        })
      #else
        SettingsView(logoutAction: {
            Task.init(priority:.userInitiated) {
                await self.store.logout()
            }
        })
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
    @EnvironmentObject var store: AccountStore
    
    @AppStorage("accentColor") private var accentColor: Color = .purple
    @AppStorage("showDeveloperSettings") private var showDeveloperSettings = false
    
    @StateObject private var appIconTitle = AppIconTitle()
    let logoutAction: () -> Void

    private let bundleVersion = Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as! String
    private let pusherUrl = Bundle.main.object(forInfoDictionaryKey: "NioPusherUrl") as? String
    
    @Environment(\.presentationMode) private var presentationMode

    /// Update the pusher config for the accountStore
    private func updatePusher() {
        Task(priority: .userInitiated) {
            guard let deviceToken = AppDelegate.shared.deviceToken else {
                // TODO: show banner informing of missing token
                print("missing deviceToken")
                return
            }
            
            guard let pusherUrl = pusherUrl else {
                // should never happen
                print("pusherUrl not set")
                return
            }
            
            do {
                try await store.setPusher(url: pusherUrl, deviceToken: deviceToken)
            } catch {
                // TODO: inform of failure
                print("failed to update pusher: \(error.localizedDescription)")
            }
            print("pusher updated")
            // TODO: inform of success
        }
    }
    
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
                    Button(action: self.logoutAction) {
                       Text(verbatim: L10n.Settings.logOut)
                    }
                }
                
                Section("Version") {
                    Text(bundleVersion)
                }
                .onTapGesture {
                    showDeveloperSettings.toggle()
                    // TODO: show banner informing of activated developer settings
                }
                
                if showDeveloperSettings {
                    Section("Developer") {
                        Button(action: updatePusher) {
                            Text("Refresh pusher config")
                        }.disabled(pusherUrl == nil || (pusherUrl?.isEmpty ?? true))
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
