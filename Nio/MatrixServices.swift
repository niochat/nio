import Foundation
import Combine
import SwiftMatrixSDK

class MatrixServices {
    var credentials: MXCredentials?
    var client: MXRestClient?
    var session: MXSession?

    static var shared = MatrixServices()

    func login(username: String, password: String, homeserver: URL) -> AnyPublisher<LoginState, Error> {
//        let options = MXSDKOptions.sharedInstance()
//        options.enableCryptoWhenStartingMXSession = true

        self.client = MXRestClient(homeServer: homeserver, unrecognizedCertificateHandler: nil)

        return Future { promise in
            self.client!.login(username: username, password: password) { response in
                switch response {
                case .failure(let error):
                    print(error)
                    promise(.failure(error))
                case .success(let credentials):
                    self.credentials = credentials

                    self.client = MXRestClient(credentials: self.credentials!, unrecognizedCertificateHandler: nil)
                    self.session = MXSession(matrixRestClient: self.client!)
                    let fileStore = MXFileStore()
                    self.session!.setStore(fileStore) { response in
                        switch response {
                        case .failure(let error):
                            print(error)
                            // TODO: Handle error, Seaglass retries with a 5 second delay in this case
                            promise(.failure(error))
                        case .success:
                            self.session!.start { response in
                                switch response {
                                case .failure(let error):
                                    print(error)
                                    promise(.failure(error))
                                case .success:
                                    promise(.success(.loggedIn))
                                }
                            }
                        }
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }

//    func start(with credentials: MXCredentials) {
//
//    }
}
