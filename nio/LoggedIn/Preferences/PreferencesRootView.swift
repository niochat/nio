//
//  PreferencesRootView.swift
//  Nio
//
//  Created by Finn Behrens on 21.04.22.
//

import SwiftUI
import NioKit

struct PreferencesRootView: View {
    @EnvironmentObject var store: NioAccountStore
    @EnvironmentObject var deepLinker: DeepLinker

    var body: some View {
        List(store.accounts, id: \.mxID) { account in
            NavigationLink(tag: .account(account.mxID), selection: $deepLinker.preferenceSelector) {
                AccountPreferencesView()
                    .environmentObject(account)
                    .tag(account.mxID)
            } label: {
                Text(account.info.name)
            }
        }
        .navigationViewStyle(.stack)
        .navigationTitle("Settings")
        .onAppear{
            print(deepLinker)
        }
    }
}

struct PreferencesRootView_Previews: PreviewProvider {
    static var previews: some View {
        PreferencesRootView()
    }
}
