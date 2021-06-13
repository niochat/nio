//
//  MXSession+async.swift
//  Masui
//
//  Created by Finn Behrens on 11.06.21.
//

import Foundation
import MatrixSDK

extension MXSession {
    public func logout() async throws {
        return try await withCheckedThrowingContinuation {continuation in
            self.logout(completion: {resp in
                switch resp {
                case .success(_):
                    continuation.resume()
                case .failure(let e):
                    continuation.resume(throwing: e)
                @unknown default:
                    continuation.resume(throwing: NioUnknownContinuationSwitchError(value: resp))
                }
            })
        }
    }
    
    public func setStore(_ store: MXStore) async throws {
        return try await withCheckedThrowingContinuation {continuation in
            self.setStore(store, completion: {resp in
                switch resp {
                case .success(_):
                    continuation.resume()
                case .failure(let e):
                    continuation.resume(throwing: e)
                @unknown default:
                    continuation.resume(throwing: NioUnknownContinuationSwitchError(value: resp))
                }
            })
        }
    }
    
    public func start(withSyncFilterId filterId: String? = nil) async throws {
        return try await withCheckedThrowingContinuation {continuation in
            self.start(withSyncFilterId: filterId) {resp in
                switch resp {
                case .success(_):
                    continuation.resume()
                case .failure(let e):
                    continuation.resume(throwing: e)
                @unknown default:
                    continuation.resume(throwing: NioUnknownContinuationSwitchError(value: resp))
                }
            }
        }
    }
}

struct NioUnknownContinuationSwitchError: Error {
    let value: Any
}
