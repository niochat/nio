import Foundation
import Combine
import SwiftMatrixSDK
import KeychainItem

class MatrixStore: ObservableObject {
    var objectWillChange = ObservableObjectPublisher()

    init() {
        if CommandLine.arguments.contains("-clear-keychain-on-launch") {
            mxid = nil
            password = nil
            self.objectWillChange.send()
        }
    }

    // MARK: Account Handling

    @KeychainItem(account: "nio.account.mxid")
    var mxid: String?

    @KeychainItem(account: "nio.account.password")
    var password: String?

    func login(username: String, password: String, homeserver: URL) {
        // TODO: Implement me
        self.mxid = username
        self.password = password

        self.objectWillChange.send()
    }

    var isLoggedIn: Bool {
        if mxid == nil || password == nil {
            return false
        }
        return true
    }
}
