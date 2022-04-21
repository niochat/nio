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

    @AppStorage("LastSelectedAccount") var currentSelectedAccountName: String = ""

    var body: some View {
        NavigationView {
            MenuContainerView {
                /* List{
                     ForEach(rooms, id: \.roomID) { room in
                         HStack {
                             Text(room.roomID!)
                             Text(room.name ?? "")
                             Text(room.owningAccount?.displayName ?? "foo")
                         }
                     }
                 } */
                Text("foo")
            }.task {
                /* if self.currentSelectedAccount == nil {
                     self.currentSelectedAccountName = store.accounts.keys.first ?? ""
                 }

                 self.currentSelectedAccount = store.accounts[self.currentSelectedAccountName] */
            }
        }
    }
}

struct LoggedInRootView_Previews: PreviewProvider {
    static var previews: some View {
        LoggedInRootView()
    }
}
