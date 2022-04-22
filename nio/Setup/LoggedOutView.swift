//
//  LoggedOutView.swift
//  Nio
//
//  Created by Finn Behrens on 22.04.22.
//

import MatrixCore
import NioKit
import NioUIKit
import SwiftUI

struct LoggedOutView: View {
    @EnvironmentObject var store: NioAccountStore

    var body: some View {
        NavigationView {
            List {
                NavigationLink("Register") {
                    Text("TODO")
                }

                NavigationLink("Login") {
                    LoginContainerView { homeserver, response in
                        Task {
                            do {
                                try await store.addAccount(homeserver: homeserver, login: response)
                            } catch {
                                NioAccountStore.logger.fault("Failed to login: \(error.localizedDescription)")
                            }
                        }
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

struct LoggedOutView_Previews: PreviewProvider {
    static var previews: some View {
        LoggedOutView()
    }
}
