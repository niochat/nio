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
    //@Environment(\.deepLinker) var deepLinker
    @EnvironmentObject var deepLinker: DeepLinker

    @State var search: String = ""

    @AppStorage("LastSelectedAccount") var currentSelectedAccountName: String = ""

    var body: some View {
        NavigationView {
            HStack {
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
                            withAnimation {
                                deepLinker.preferenceSelector = nil
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

                NavigationLink(tag: DeepLinker.MainSelector.preferences, selection: $deepLinker.mainSelection, destination: { PreferencesRootView() }, label: { EmptyView() })
            }
        }
    }
}

struct LoggedInRootView_Previews: PreviewProvider {
    static var previews: some View {
        LoggedInRootView()
    }
}
