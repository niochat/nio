//
//  NioApp.swift
//  Nio
//
//  Created by Finn Behrens on 21.03.22.
//

import MatrixCore
import NioKit
import OSLog
import SwiftUI

@main
struct NioApp: App {
    init() {
        Task {
            if CommandLine.arguments.contains("-clear-stored-credentials") {
                NioAccountStore.removeAllKeychainEntries()
                NioAccountStore.logger.info("🗑 cleared stored credentials from keychain")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
