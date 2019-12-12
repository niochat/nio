import SwiftUI

struct UserIDKey: EnvironmentKey {
    static let defaultValue: String = ""
}

extension EnvironmentValues {
    var userID: String {
        get {
            return self[UserIDKey.self]
        }
        set {
            self[UserIDKey.self] = newValue
        }
    }
}
