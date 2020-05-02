import Foundation

class SessionManager {
    static let shared = SessionManager()

    private var sessions: [String: Session]

    init() {
        self.sessions = [:]
    }

    func session(for account: Account) -> Session? {
        if let session = self.sessions[account.userId] {
            return session
        }

        let session = Session(account: account)
        sessions[account.userId] = session
        return session
    }
}
