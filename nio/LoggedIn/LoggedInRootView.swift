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
    // @Environment(\.deepLinker) var deepLinker
    @EnvironmentObject var deepLinker: DeepLinker

    @State var search: String = ""

    @AppStorage("LastSelectedAccount") var currentSelectedAccountName: String = ""

    var body: some View {
        NavigationView {
            List {
                NavigationLink(
                    tag: .all,
                    selection: $deepLinker.mainSelection,
                    destination: { Text("All") },
                    label: { Label("All Rooms", systemImage: "tray.2") }
                )
                NavigationLink(
                    tag: .favourites,
                    selection: $deepLinker.mainSelection,
                    destination: { Text("Favs") },
                    label: {
                        Label("Favourites", systemImage: "star")
                            .tint(.yellow)
                    }
                )

                ForEach(store.accounts, id: \.mxID) { account in
                    AccountListAccountSectionView(searchText: $search)
                        .environmentObject(account)
                        .tag(account.mxID)
                }

                // Hidden settings View
                NavigationLink(
                    tag: DeepLinker.MainSelector.preferences,
                    selection: $deepLinker.mainSelection,
                    destination: { PreferencesRootView() },
                    label: { EmptyView() }
                )
            }
            // .searchable(text: $search)
            .listStyle(.sidebar)
            .navigationTitle("Accounts")
            .toolbar {
                ToolbarItem(id: "more", placement: .primaryAction) {
                    Menu {
                        Button {
                            withAnimation {
                                deepLinker.preferenceSelection = nil
                                deepLinker.mainSelection = .preferences
                            }
                        } label: {
                            Label("Settings", systemImage: "gear")
                        }
                    } label: {
                        Label("Settings", systemImage: "ellipsis.circle")
                    }
                }
            }
        }
    }
}

struct LoggedInRootView_Previews: PreviewProvider {
    static var previews: some View {
        LoggedInRootView()
    }
}
