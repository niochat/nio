import Foundation
import Combine
import SwiftMatrixSDK
import KeychainAccess

extension MXCredentials {
    func save(to keychain: Keychain) {
        guard
            let homeserver = self.homeServer,
            let userId = self.userId,
            let accessToken = self.accessToken
        else {
            return
        }
        keychain["homeserver"] = homeserver
        keychain["userId"] = userId
        keychain["accessToken"] = accessToken
    }

    static func from(_ keychain: Keychain) -> MXCredentials? {
        print("looking for existing credentials in keychain")
        guard
            let homeserver = keychain["homeserver"],
            let userId = keychain["userId"],
            let accessToken = keychain["accessToken"]
        else {
            return nil
        }
        return MXCredentials(homeServer: homeserver, userId: userId, accessToken: accessToken)
    }
}

class MatrixServices {
    let keychain = Keychain(service: "chat.nio.credentials")
    var store: MatrixStore<AppState, AppAction>?

    var credentials: MXCredentials?

    var client: MXRestClient?
    var session: MXSession?

    static var shared = MatrixServices()

    init() {
        if let credentials = MXCredentials.from(keychain) {
            self.store?.send(AppAction.loginState(.authenticating))
            self.start(with: credentials) { result in
                switch result {
                case .failure(let error):
                    print("Error on starting session with saved credentials: \(error)")
                    self.store?.send(AppAction.loginState(.failure(error)))
                case .success(let state):
                    self.store?.send(AppAction.loginState(state))
                }
            }
        }
    }

    func login(username: String, password: String, homeserver: URL) -> AnyPublisher<LoginState, Error> {
//        let options = MXSDKOptions.sharedInstance()
//        options.enableCryptoWhenStartingMXSession = true

        self.client = MXRestClient(homeServer: homeserver, unrecognizedCertificateHandler: nil)

        return Future { promise in
            self.client!.login(username: username, password: password) { response in
                switch response {
                case .failure(let error):
                    print("Error on starting session with new credentials: \(error)")
                    promise(.failure(error))
                case .success(let credentials):
                    credentials.save(to: self.keychain)

                    self.start(with: credentials) { result in
                        switch result {
                        case .failure(let error):
                            promise(.failure(error))
                        case .success(let state):
                            promise(.success(state))
                        }
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func start(with credentials: MXCredentials, completion: @escaping (Result<LoginState, Error>) -> Void) {
        self.credentials = credentials
        self.client = MXRestClient(credentials: self.credentials!, unrecognizedCertificateHandler: nil)
        self.session = MXSession(matrixRestClient: self.client!)
        let fileStore = MXFileStore()

        self.session!.setStore(fileStore) { response in
            switch response {
            case .failure(let error):
                completion(.failure(error))
            case .success:
                self.session!.start { response in
                    switch response {
                    case .failure(let error):
                        completion(.failure(error))
                    case .success:
                        completion(.success(.loggedIn))
                    }
                }
            }
        }
    }
}
