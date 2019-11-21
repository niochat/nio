import Foundation
import Combine
import SwiftMatrixSDK

extension MXRestClient {
    func loginPublisher(username: String, password: String) -> AnyPublisher<MXCredentials, Error> {
        Future<MXCredentials, Error> { promise in
            self.login(username: username, password: password) { response in
                switch response {
                case .failure(let error):
                    promise(.failure(error))
                case .success(let credentials):
                    promise(.success(credentials))
                }
            }
        }.eraseToAnyPublisher()
    }
}
