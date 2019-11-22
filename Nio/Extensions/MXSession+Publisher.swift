import Foundation
import Combine
import SwiftMatrixSDK

extension MXSession {
    func startPublisher() -> AnyPublisher<MXSession, Error> {
        Future<MXSession, Error> { promise in
            self.start { response in
                switch response {
                case .failure(let error):
                    promise(.failure(error))
                case .success:
                    promise(.success(self))
                }
            }
        }.eraseToAnyPublisher()
    }
}
