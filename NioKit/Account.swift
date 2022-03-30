//
//  Account.swift
//  Nio
//
//  Created by Finn Behrens on 24.03.22.
//

import Foundation
import MatrixClient
import MatrixCore
import OSLog

@MainActor
public class NioAccountStore: ObservableObject {
    public static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "accountStore")

    public static let shared = NioAccountStore()

    @Published public internal(set) var accounts: [String: NioAccount]
    public internal(set) var store = MatrixStore.shared

    // MARK: - init

    private init() {
        accounts = [:]

        Task {
            do {
                try await self.runInit()
            } catch {
                print(error)
            }
        }
    }

    private func runInit() async throws {
        let accounts = try await MatrixCore.loadFromCoreData()

        for account in accounts {
            self.accounts[await account.userID.FQMXID!] = await NioAccount(account)
        }

        NioAccountStore.logger.info("Finished loading from CoreData")
    }

    // MARK: - dynamic variables

    public var hasAccount: Bool {
        accounts.count != 0
    }

    // MARK: - Create account

    public func addAccount(homeserver: MatrixHomeserver, login: MatrixLogin) async {
        do {
            let account = try await MatrixCore(homeserver: homeserver, login: login, matrixStore: store)
            accounts[await account.userID.FQMXID!] = await NioAccount(account)
        } catch {
            NioAccountStore.logger.fault("Failed to create MatrixCore instance: \(error.localizedDescription)")
            assertionFailure("Login did not create a MatrixCore instance")
        }
        NioAccountStore.logger.debug("Added new Account to store")
    }
}

@MainActor
public class NioAccount: ObservableObject {
    let matrixCore: MatrixCore

    public init(_ account: MatrixCore) async {
        matrixCore = account
    }
}
