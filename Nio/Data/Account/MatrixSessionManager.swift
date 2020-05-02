import Foundation

class MatrixSessionManager {
    static let shared = MatrixSessionManager()

    private var sessions: [String: MatrixSession]

    init() {
        self.sessions = [:]
    }

    func session(for account: MatrixAccount) -> MatrixSession? {
        if let session = self.sessions[account.userId] {
            return session
        }

        let session = MatrixSession(account: account)
        sessions[account.userId] = session
        return session
    }
}
