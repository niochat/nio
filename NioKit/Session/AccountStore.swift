import Foundation
import Combine
import SwiftMatrixSDK
import KeychainAccess

public enum LoginState {
    case loggedOut
    case authenticating
    case failure(Error)
    case loggedIn(userId: String)
}

public class AccountStore: ObservableObject {
    public var client: MXRestClient?
    public var session: MXSession?

    var fileStore: MXFileStore?
    var credentials: MXCredentials?

    let keychain = Keychain(
        service: "chat.nio.credentials",
        //accessGroup: ((Bundle.main.infoDictionary?["DevelopmentTeam"] as? String) ?? "") + ".nio.keychain")
        accessGroup: "VL26UCY4XZ.nio.keychain")

    public init() {
        if CommandLine.arguments.contains("-clear-stored-credentials") {
            print("🗑 cleared stored credentials from keychain")
            MXCredentials
                .from(keychain)?
                .clear(from: keychain)
        }

        if let credentials = MXCredentials.from(keychain) {
            self.loginState = .authenticating
            self.credentials = credentials
            self.sync { result in
                switch result {
                case .failure(let error):
                    print("Error on starting session with saved credentials: \(error)")
                    self.loginState = .failure(error)
                case .success(let state):
                    self.loginState = state
                }
            }
        }
    }

    deinit {
        self.session?.removeListener(self.listenReference)
    }

    // MARK: - Login & Sync

    @Published public var loginState: LoginState = .loggedOut

    public func login(username: String, password: String, homeserver: URL) {
        self.loginState = .authenticating

        let options = MXSDKOptions()
        options.enableCryptoWhenStartingMXSession = true

        self.client = MXRestClient(homeServer: homeserver, unrecognizedCertificateHandler: nil)

        self.client?.login(username: username, password: password) { response in
            switch response {
            case .failure(let error):
                print("Error on starting session with new credentials: \(error)")
                self.loginState = .failure(error)
            case .success(let credentials):
                self.credentials = credentials
                credentials.save(to: self.keychain)
                print("Error on starting session with new credentials:")

                self.sync { result in
                    switch result {
                    case .failure(let error):
                        // Does this make sense? The login itself didn't fail, but syncing did.
                        self.loginState = .failure(error)
                    case .success(let state):
                        self.loginState = state
                    }
                }
            }
        }
    }

    public func logout(completion: @escaping (Result<LoginState, Error>) -> Void) {
        self.credentials?.clear(from: keychain)

        self.session?.logout { response in
            switch response {
            case .failure(let error):
                completion(.failure(error))
            case .success:
                self.fileStore?.deleteAllData()
                completion(.success(.loggedOut))
            }
        }
    }

    public func logout() {
        self.logout { result in
            switch result {
            case .failure:
                // Close the session even if the logout request failed
                self.loginState = .loggedOut
            case .success(let state):
                self.loginState = state
            }
        }
    }

    func sync(completion: @escaping (Result<LoginState, Error>) -> Void) {
        guard let credentials = self.credentials else { return }

        self.client = MXRestClient(credentials: credentials, unrecognizedCertificateHandler: nil)
        self.session = MXSession(matrixRestClient: self.client!)
        self.fileStore = MXFileStore()

        self.session!.setStore(fileStore!) { response in
            switch response {
            case .failure(let error):
                completion(.failure(error))
            case .success:
                self.session?.start { response in
                    switch response {
                    case .failure(let error):
                        completion(.failure(error))
                    case .success:
                        let userId = credentials.userId!
                        completion(.success(.loggedIn(userId: userId)))
                    }
                }
            }
        }
    }

    // MARK: - Rooms

    var listenReference: Any?

    public func startListeningForRoomEvents() {
        // roomState is nil for presence events, just for future reference
        listenReference = self.session?.listenToEvents { event, direction, roomState in
            let affectedRooms = self.rooms.filter { $0.summary.roomId == event.roomId }
            for room in affectedRooms {
                room.add(event: event, direction: direction, roomState: roomState as? MXRoomState)
            }
            self.objectWillChange.send()
        }
    }

    public var rooms: [NIORoom] {
        return self.session?.rooms
            .map { NIORoom($0) }
            .sorted { $0.summary.lastMessageDate > $1.summary.lastMessageDate }
            ?? []
    }
}
