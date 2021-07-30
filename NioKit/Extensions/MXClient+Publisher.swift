import Combine
import Foundation
import MatrixSDK

public extension MXRestClient {
    func nio_publicRooms(onServer: String? = nil, limit: UInt? = nil) -> AnyPublisher<MXPublicRoomsResponse, Error> {
        Future<MXPublicRoomsResponse, Error> { promise in
            self.publicRooms(onServer: onServer, limit: limit) { response in
                switch response {
                case let .failure(error):
                    promise(.failure(error))
                case let .success(publicRoomsResponse):
                    promise(.success(publicRoomsResponse))
                @unknown default:
                    fatalError("Unexpected Matrix response: \(response)")
                }
            }
        }.eraseToAnyPublisher()
    }
}
