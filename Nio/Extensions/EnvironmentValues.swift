import SwiftUI

struct UserIDKey: EnvironmentKey {
    static let defaultValue: String = ""
}

struct HomeserverKey: EnvironmentKey {
    static let defaultValue = URL(string: "https://matrix.org")!
}

extension EnvironmentValues {
    var userId: String {
        get {
            return self[UserIDKey.self]
        }
        set {
            self[UserIDKey.self] = newValue
        }
    }

    var homeserver: URL {
        get {
            return self[HomeserverKey.self]
        }
        set {
            self[HomeserverKey.self] = newValue
        }
    }
}
