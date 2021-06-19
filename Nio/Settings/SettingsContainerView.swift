//
//  SettingsContainerView.swift
//  Nio
//
//  Created by Finn Behrens on 13.06.21.
//  Copyright © 2021 Kilian Koeltzsch. All rights reserved.
//

import SwiftUI

import NioKit

struct SettingsContainerView: View {
    @EnvironmentObject var store: AccountStore

    var body: some View {
           SettingsView(logoutAction: {
            async {
                await self.store.logout()
            }
        })
    }
}

private struct SettingsView: View {
    @AppStorage("accentColor") private var accentColor: Color = .purple
    @AppStorage("showDeveloperSettings") private var showDeveloperSettings = false
    
    @StateObject private var appIconTitle = AppIconTitle()
    let logoutAction: () -> Void
    
    private let bundleVersion = Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as! String

    @Environment(\.presentationMode) private var presentationMode

    /// Show a info banner for e.g. changing the developer setting
    func showInfoBanner(_ text: String, body: String? = nil, identifier: String) {
        // TODO: fallback if notifications is disabled
        print("trying to show banner")
        asyncDetached {
            let notification = UNMutableNotificationContent()
            notification.title = text
            if let body = body {
                notification.body = body
            }
            notification.sound = UNNotificationSound.default
            notification.userInfo = ["settings": identifier]
            //notification.title = "Settings changed"
            notification.badge = await UIApplication.shared.applicationIconBadgeNumber as NSNumber
            
            let request = UNNotificationRequest(identifier: identifier, content: notification, trigger: nil)
            
            //request.
            do {
                try await UNUserNotificationCenter.current().add(request)
            } catch {
                print("failed to schedule notification: \(error.localizedDescription)")
            }
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
                        .onTapGesture {
                            showDeveloperSettings.toggle()
                            let text = showDeveloperSettings ? "Developer settings activated" : "Developer settings deactivated"
                            showInfoBanner(text, identifier: "chat.nio.developer-settings.show")
                        }
                }
                
                if showDeveloperSettings {
                    Section("Developer") {
                        Button(action: {
                            async {
                                await AccountStore.deleteSkItems()
                                showInfoBanner("Sirikit Donations cleared", identifier: "chat.nio.developer-settings.sk-cleared")
                            }
                        }) {
                            Text("delete sk items")
                        }
                        
                        Button(action: {
                            async {
                                do {
                                    try await AccountStore.shared.setPusher()
                                    showInfoBanner("Pusher repushed", identifier: "chat.nio.developer-settings.reset-pusher")
                                } catch {
                                    print("failed to reset pusher")
                                    showInfoBanner("Pusher update failed", body: error.localizedDescription, identifier: "chat.nio.developer-settings.reset-pusher")
                                }
                            }
                        }) {
                            Text("refresh pusher config")
                        }
                        
                        Text("\(AccountStore.shared.session?.crypto.crossSigning.state.rawValue ?? -1)")
                            .onTapGesture {
                                AccountStore.shared.session?.crypto.crossSigning.refreshState(success: nil, failure: nil)
                            }
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


struct SettingsContainerView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsContainerView()
    }
}
