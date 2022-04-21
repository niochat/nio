//
//  RootView.swift
//  Nio
//
//  Created by Finn Behrens on 21.03.22.
//

import MatrixCore
import NioKit
import NioUIKit
import SwiftUI

/* struct RootView: View {
     @ObservedObject var store = NioAccountStore.shared

     var body: some View {
         if store.hasAccount {
             LoggedInRootView()
                 .environment(\.managedObjectContext, MatrixStore.shared.viewContext)
                 .environmentObject(store)
         } else {
             NavigationView {
                 VStack {
                     NavigationLink("Register") {
                         RegisterContainer(callback: { _, _ in
                             // TODO:
                         })
                     }
                     NavigationLink("Login") {
                         LoginContainerView { homeserver, response in
                             Task {
                                 await store.addAccount(homeserver: homeserver, login: response)
                             }
                         }
                     }
                     NavigationLink("debug") {
                         Button("test") {
                             Task {
                                 do {
                                     // try await account.store.addMatrixAccount(homeserver: .init(resolve: "https://matrix.org"), userID: "@kloenk_nio:matrix.org")
                                 } catch {
                                     print(error)
                                 }
                             }
                         }

                         Button("deleteAll") {
                             Task {
                                 do {
                                     try await MatrixStore.shared.deleteAll()
                                 } catch {
                                     fatalError("\(error.localizedDescription)")
                                 }
                             }
                         }
                     }
                 }
             }
             /* RegisterContainer(callback: { token in
                  print("token: \(token)")
              }) */
         }
     }
 } */

struct RootView: View {
    var body: some View {
        LoggedInRootView()
            .environmentObject(NioAccountStore.preview)
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
    }
}
