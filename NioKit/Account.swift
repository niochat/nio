//
//  Account.swift
//  Nio
//
//  Created by Finn Behrens on 18.04.22.
//

import Foundation
import MatrixClient
import MatrixCore

@MainActor
public class NioAccount: ObservableObject, Comparable, Identifiable {
    @Published public var core: MatrixCore<Store>

    public var store: Store {
        core.store
    }

    public var mxID: MatrixFullUserIdentifier {
        core.mxID
    }

    public var displayName: String? {
        core.info.displayName
    }

    public init(core: MatrixCore<Store>) {
        self.core = core
    }

    // MARK: - Secret managemant

    public func setAccessToken(accessToken: String) async throws {
        core.client.accessToken = accessToken
        core.accessToken = accessToken

        try await store.saveAccountInfo(account: info)
    }

    public func logout() async throws {
        try await core.logout()
    }
}

public extension NioAccount {
    /* var id: Store.AccountInfo.AccountIdentifier {
         core.id
     } */

    static func == (lhs: NioAccount, rhs: NioAccount) -> Bool {
        lhs.mxID == rhs.mxID
    }

    static func < (lhs: NioAccount, rhs: NioAccount) -> Bool {
        lhs.mxID < rhs.mxID
    }
}
