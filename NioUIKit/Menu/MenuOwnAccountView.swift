//
//  MenuOwnAccountView.swift
//  NioUIKit_iOS
//
//  Created by Finn Behrens on 30.03.22.
//

import MatrixCore
import NioKit
import SwiftUI

struct MenuOwnAccountContainerView: View {
    var body: some View {
        MenuOwnAccountView()
        Text("TODO")
    }
}

struct MenuOwnAccountView: View {
    @EnvironmentObject var store: NioAccountStore

    var body: some View {
        VStack(alignment: .leading) {
            NavigationLink {
                Text("Account")
            } label: {
                MenuAccountPickerAccountView(account: store.getAccount!)
            }
            // TODO: add a banner if no accounts are returned, because of an Invalid currentAccount?
        }
    }
}

struct MenuOwnAccountView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            /* MenuOwnAccountView(currentAccount: "@amir_sanders:example.com")
             .environment(\.managedObjectContext, MatrixStore.preview.viewContext)
             .previewLayout(.fixed(width: 300, height: 60)) */
        }
    }
}
