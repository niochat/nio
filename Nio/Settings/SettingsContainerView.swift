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


struct SettingsContainerView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsContainerView()
    }
}
