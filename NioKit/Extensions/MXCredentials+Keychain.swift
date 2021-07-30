import KeychainAccess
import MatrixSDK

public extension MXCredentials {
    func save(to keychain: Keychain) {
        guard
            let homeserver = homeServer,
            let userId = self.userId,
            let accessToken = self.accessToken,
            let deviceId = self.deviceId
        else {
            return
        }
        keychain["homeserver"] = homeserver
        keychain["userId"] = userId
        keychain["accessToken"] = accessToken
        keychain["deviceId"] = deviceId
    }

    func clear(from keychain: Keychain) {
        keychain["homeserver"] = nil
        keychain["userId"] = nil
        keychain["accessToken"] = nil
        keychain["deviceId"] = nil
    }

    static func from(_ keychain: Keychain) -> MXCredentials? {
        guard
            let homeserver = keychain["homeserver"],
            let userId = keychain["userId"],
            let accessToken = keychain["accessToken"],
            let deviceId = keychain["deviceId"]
        else {
            return nil
        }
        let credentials = MXCredentials(
            homeServer: homeserver,
            userId: userId,
            accessToken: accessToken
        )
        credentials.deviceId = deviceId
        return credentials
    }
}
