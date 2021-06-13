//
//  SettingsContainerView.swift
//  Mio
//
//  Created by Finn Behrens on 13.06.21.
//  Copyright © 2021 Kilian Koeltzsch. All rights reserved.
//

import SwiftUI

import NioKit

struct SettingsContainerView: View {
    @EnvironmentObject var store: AccountStore

    var body: some View {
        MacSettingsView(logoutAction: {
            async {
                await self.store.logout()
            }
        })
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

struct SettingsContainerView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsContainerView()
    }
}
