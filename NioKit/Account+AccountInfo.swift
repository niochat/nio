//
//  Account+AccountInfo.swift
//  Nio
//
//  Created by Finn Behrens on 21.04.22.
//

import Foundation

public extension NioAccount {
    var info: Store.AccountInfo {
        get {
            core.info
        }
        set {
            core.info = newValue
            objectWillChange.send()
        }
    }

    /// Write AccountInfo to Store
    func updateInfo() async throws {
        try await store.saveAccountInfo(account: info)
    }
}
