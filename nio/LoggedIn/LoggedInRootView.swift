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

    @AppStorage("LastSelectedAccount") var currentSelectedAccountName: String = ""

    var body: some View {
        NavigationView {
            List(store.accounts, id: \.mxID) {
                AccountListAccountSectionView(searchText: $search).environmentObject($0).tag($0.mxID)
            }
            //.searchable(text: $search)
            .listStyle(.sidebar)
            .toolbar {
                ToolbarItem() {
                    Button(action: {
                        print("foo")
                    }, label: { Image(systemName: "ellipse") })
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
