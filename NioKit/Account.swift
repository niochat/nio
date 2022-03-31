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
import Security

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
            await addAccount(account: account)
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
            await addAccount(account: account)
        } catch {
            NioAccountStore.logger.fault("Failed to create MatrixCore instance: \(error.localizedDescription)")
            assertionFailure("Login did not create a MatrixCore instance")
        }
        NioAccountStore.logger.debug("Added new Account to store")
    }

    internal func addAccount(account: MatrixCore) async {
        let nioAccount = await NioAccount(account)
        accounts[nioAccount.userID.FQMXID!] = nioAccount
    }

    // MARK: - logout

    public func logout(account: NioAccount) async throws {
        let userID = account.userID.FQMXID!
        accounts.removeValue(forKey: userID)

        try await account.logout()
    }

    public func logout(accountName: String) async throws {
        guard let account = accounts.removeValue(forKey: accountName) else {
            return
        }

        try await account.logout()
    }

    public static func removeAllKeychainEntries() {
        var keychainQuery = MatrixCoreSettings.extraKeychainArguments

        keychainQuery[kSecClass as String] = kSecClassInternetPassword

        let status = SecItemDelete(keychainQuery as CFDictionary)
        guard status == errSecSuccess else {
            NioAccountStore.logger.fault("Failed to delete keychain items: \(status)")
            return
        }
    }
}

@MainActor
public class NioAccount: ObservableObject {
    public let matrixCore: MatrixCore
    public let userID: MatrixUserIdentifier

    // MARK: Computed variables

    public var displayName: String? {
        matrixCore.displayName
    }

    public init(_ account: MatrixCore) async {
        matrixCore = account
        userID = account.userID

        Task {
            try await self.matrixCore.updateDisplayName()
        }
    }

    public func logout() async throws {
        try await matrixCore.logout()
    }
}
