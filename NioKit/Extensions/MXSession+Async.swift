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
    
    //store.session?.event(withEventId: <#T##String!#>, inRoom: <#T##String!#>, success: <#T##((MXEvent?) -> Void)!##((MXEvent?) -> Void)!##(MXEvent?) -> Void#>, failure: <#T##((Error?) -> Void)!##((Error?) -> Void)!##(Error?) -> Void#>)

    public func event(withEventId event: MXEvent.MXEventId, inRoom room: MXRoom.MXRoomId) async throws -> MXEvent? {
        return try await withCheckedThrowingContinuation {continuation in
            self.event(withEventId: event.id, inRoom: room.id, success: { continuation.resume(returning: $0) }, failure: { continuation.resume(throwing: $0!) })
        }
    }
}

struct NioUnknownContinuationSwitchError: Error {
    let value: Any
}
