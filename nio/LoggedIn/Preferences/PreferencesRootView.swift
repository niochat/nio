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

    var body: some View {
        //NavigationView() {
            List(store.accounts, id: \.mxID) { account in
                NavigationLink {
                AccountPreferencesView()
                    .environmentObject(account)
                    .tag(account.mxID)
                } label: {
                    Text(account.info.name)
                }
            }
        //}
        .navigationViewStyle(.stack)
        .navigationTitle("Settings")
    }
}

struct PreferencesRootView_Previews: PreviewProvider {
    static var previews: some View {
        PreferencesRootView()
    }
}
