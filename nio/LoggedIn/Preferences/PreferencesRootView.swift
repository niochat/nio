//
//  PreferencesRootView.swift
//  Nio
//
//  Created by Finn Behrens on 21.04.22.
//

import NioKit
import SwiftUI

struct PreferencesRootView: View {
    @EnvironmentObject var store: NioAccountStore
    @EnvironmentObject var deepLinker: DeepLinker

    var body: some View {
        /* List(store.accounts, id: \.mxID) { account in
             NavigationLink(tag: .account(account.mxID), selection: $deepLinker.preferenceSelector) {
                 AccountPreferencesView()
                     .environmentObject(account)
                     .tag(account.mxID)
             } label: {
                 Text(account.info.name)
             }
         } */
        List {
            Section("accounts") {
                ForEach(store.accounts, id: \.mxID) { account in
                    NavigationLink(
                        tag: .account(account.mxID),
                        selection: $deepLinker.preferenceSelection,
                        destination: {
                            AccountPreferencesView()
                                .environmentObject(account)
                                .tag(account.mxID)
                        },
                        label: {
                            Label(account.info.name, systemImage: "person.circle")
                        }
                    )
                }

                NavigationLink(
                    tag: .newAccount,
                    selection: $deepLinker.preferenceSelection,
                    destination: {
                        EmptyView()
                    },
                    label: {
                        Label("Add Account", systemImage: "plus.circle")
                    }
                )
            }

            Section("App Settings") {
                NavigationLink(
                    tag: .icon,
                    selection: $deepLinker.preferenceSelection,
                    destination: {
                        PreferencesAppIcon()
                    },
                    label: {
                        HStack {
                            Text("App Icon")
                            Spacer(minLength: 5)
                            Text(UIApplication.shared.alternateIconName ?? "Nio")
                        }
                    }
                )
            }
        }
        .navigationViewStyle(.stack)
        .navigationTitle("Settings")
    }
}

struct PreferencesRootView_Previews: PreviewProvider {
    static var previews: some View {
        // NavigationView {
        PreferencesRootView()
            .environmentObject(NioAccountStore.preview)
            .environmentObject(DeepLinker())
        // }
    }
}
