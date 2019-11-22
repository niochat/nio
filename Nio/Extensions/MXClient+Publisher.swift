import Foundation
import Combine
import SwiftMatrixSDK

extension MXRestClient {
    func nio_login(username: String, password: String) -> AnyPublisher<MXCredentials, Error> {
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

    func nio_publicRooms(onServer: String? = nil, limit: UInt? = nil) -> AnyPublisher<MXPublicRoomsResponse, Error> {
        Future<MXPublicRoomsResponse, Error> { promise in
            self.publicRooms(onServer: onServer, limit: limit) { response in
                switch response {
                case .failure(let error):
                    promise(.failure(error))
                case .success(let publicRoomsResponse):
                    promise(.success(publicRoomsResponse))
                }
            }
        }.eraseToAnyPublisher()
    }
}
