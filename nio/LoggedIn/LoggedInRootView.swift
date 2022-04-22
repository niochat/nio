//
//  LoggedInRootVie.swift
//  Nio
//
//  Created by Finn Behrens on 26.03.22.
//

import MatrixCore
import NioKit
import NioUIKit
import SwiftUI

struct LoggedInRootView: View {
    @EnvironmentObject var store: NioAccountStore

    @State var search: String = ""

    // FIXME: change to false for prod
    @State var showSettings = false

    @AppStorage("LastSelectedAccount") var currentSelectedAccountName: String = ""

    var body: some View {
        NavigationView {
            List(store.accounts, id: \.mxID) {
                AccountListAccountSectionView(searchText: $search)
                    .environmentObject($0)
                    .tag($0.mxID)
            }
            //.searchable(text: $search)
            .listStyle(.sidebar)
            .toolbar {
                ToolbarItem(id: "more", placement: .primaryAction) {
                    Menu {
                        Button {
                            showSettings = true
                        } label: {
                            Label("Settings", systemImage: "gear")
                        }
                    } label: {
                        Label("Settings", systemImage: "ellipsis.circle")
                    }
                }
            }

            NavigationLink(destination: PreferencesRootView().onDisappear{ showSettings = false }, isActive: $showSettings, label: { EmptyView() })
        }
    }
}

struct LoggedInRootView_Previews: PreviewProvider {
    static var previews: some View {
        LoggedInRootView()
    }
}
