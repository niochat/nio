//
//  Account.swift
//  Nio
//
//  Created by Finn Behrens on 24.03.22.
//

import Foundation
import MatrixClient
import MatrixCore
import MatrixSQLiteStore
import OSLog
import Security
import SwiftUI

@MainActor
public class NioAccountStore: ObservableObject {
    public nonisolated static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "accountStore")

    // public static let shared = NioAccountStore()

    @Published public internal(set) var accounts: [NioAccount] = []

    public private(set) var store: Store

    // MARK: - computed variables

    public var hasAccounts: Bool {
        !accounts.isEmpty
    }

    // MARK: - init

    private init(preview: Bool = false) {
        if _fastPath(!preview) {
            let db = try! FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            store = try! Store(path: db.path)
        } else {
            #if DEBUG
                store = Store.inMemory()
            #else
                assertionFailure()
            #endif
        }

        Task(priority: .high) {
            do {
                try await self.runInit()
                #if DEBUG
                    if preview {
                        await self.populatePreviewData()
                    }
                #endif
            } catch {
                NioAccountStore.logger.fault("Failed to initialise: \(error.localizedDescription)")
            }
        }
    }

    private func runInit() async throws {
        let accounts = try await store.getAccounts()

        for account in accounts {
            addAccount(account)
        }
    }

    public func addAccount(_ account: MatrixCore<Store>) {
        addAccount(NioAccount(core: account))
    }

    public func addAccount(_ account: NioAccount) {
        accounts.append(account)
    }

    /// Issue logout request to homeserver and remove account from store.
    public func logoutAccount(_: String) async throws {
        // TODO:
        fatalError("TODO")
        /* guard let account = accounts[accountID] else {
             return
         }
         try await account.logout()
         accounts.removeValue(forKey: accountID)
         if currentAccount == accountID {
             currentAccount = nil
         } */
    }

    public func logoutAllAccounts() async throws {
        for account in accounts {
            try? await account.logout()
        }
        accounts = []
    }

    // MARK: - Preview

    #if DEBUG
        public static let preview = NioAccountStore(preview: true)
        public nonisolated static let exampleServer = MatrixHomeserver(string: "https://example.com/")!

        public static func generatePreviewAccount(
            _ store: NioAccountStore,
            name: String,
            domain _: String = "example.com",
            displayName: String? = nil
        ) -> NioAccount {
            let bob = Store.AccountInfo(
                name: name,
                displayName: displayName,
                mxID: MatrixFullUserIdentifier(localpart: name.lowercased(), domain: "example.com"),
                homeServer: NioAccountStore.exampleServer,
                accessToken: ""
            )
            return NioAccount(core: MatrixCore(store: store.store, account: bob))
        }

        func populatePreviewData() async {
            addAccount(NioAccountStore.generatePreviewAccount(self, name: "Bob"))
            addAccount(NioAccountStore.generatePreviewAccount(self, name: "Alice", displayName: "Alice"))
            addAccount(NioAccountStore.generatePreviewAccount(self, name: "Charlie", displayName: "Charlie"))
        }

    #endif
}

/* public class NioAccountStore: ObservableObject {
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
         account.setDefaultDelegate()
         matrixCore = account
         userID = account.userID

         do {
             try self.matrixCore.startSync()
         } catch {
             print(error)
         }

         Task {
             try await self.matrixCore.updateDisplayName()
         }
     }

     public func logout() async throws {
         try await matrixCore.logout()
     }
 }
 */
