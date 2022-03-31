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
    @Environment(\.managedObjectContext) var context

    @FetchRequest(sortDescriptors: []) var accounts: FetchedResults<MatrixAccount>

    @EnvironmentObject var store: NioAccountStore

    @AppStorage("LastSelectedAccount") var currentSelectedAccountName: String = ""

    @State var currentSelectedAccount: NioAccount?

    var body: some View {
        NavigationView {
            MenuContainerView(currentAccount: $currentSelectedAccountName) {
                Text("foo")
            }.task {
                if self.currentSelectedAccount == nil {
                    self.currentSelectedAccountName = store.accounts.keys.first ?? ""
                }

                self.currentSelectedAccount = store.accounts[self.currentSelectedAccountName]
            }
        }
    }
}

struct LoggedInRootView_Previews: PreviewProvider {
    static var previews: some View {
        LoggedInRootView()
    }
}
