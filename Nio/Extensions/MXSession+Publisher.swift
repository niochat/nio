import Foundation
import Combine
import SwiftMatrixSDK

extension MXSession {
    func nio_start() -> AnyPublisher<MXSession, Error> {
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
