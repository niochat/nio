//
//  MXRestClient+async.swift
//  Masui
//
//  Created by Finn Behrens on 11.06.21.
//

import Foundation
import MatrixSDK

extension MXRestClient {
    func login(type loginType: MatrixSDK.MXLoginFlowType = .password, username: String, password: String) async throws -> MXCredentials {
        try await withCheckedThrowingContinuation { continuation in
            self.login(type: loginType, username: username, password: password, completion: { resp in
                switch resp {
                case let .success(v):
                    continuation.resume(returning: v)
                case let .failure(e):
                    continuation.resume(throwing: e)
                @unknown default:
                    continuation.resume(throwing: NioUnknownContinuationSwitchError(value: resp))
                }
            })
        }
    }

    func wellKnown() async throws -> MXWellKnown {
        try await withCheckedThrowingContinuation { continuation in
            self.wellKnow({ continuation.resume(returning: $0!) }, failure: { continuation.resume(throwing: $0!) })
        }
    }
    
    func pushers() async throws -> [MXPusher] {
        try await withCheckedThrowingContinuation { continuation in
            self.pushers({ continuation.resume(returning: $0 ?? []) }, failure: { continuation.resume(throwing: $0!) })
        }
    }
    
    
    func setPusher(puskKey: String, kind: MXPusherKind, appId: String, appDisplayName: String, deviceDisplayName: String, profileTag: String, lang: String, data: [String: Any], append: Bool) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            self.setPusher(pushKey: puskKey, kind: kind, appId: appId, appDisplayName: appDisplayName, deviceDisplayName: deviceDisplayName, profileTag: profileTag, lang: lang, data: data, append: append, completion: {resp in
                switch resp {
                case let .success(v):
                    continuation.resume(returning: v)
                case let .failure(e):
                    continuation.resume(throwing: e)
                @unknown default:
                    continuation.resume(throwing: NioUnknownContinuationSwitchError(value: resp))
                }
            })
        }
    }
    
    public func event(withEventId event: MXEvent.MXEventId, inRoom room: MXRoom.MXRoomId) async throws -> MXEvent {
        return try await withCheckedThrowingContinuation { continuation in
            self.event(withEventId: event.id, inRoom: room.id, completion: {resp in
                switch resp {
                case let .success(v):
                    continuation.resume(returning: v)
                case let .failure(e):
                    continuation.resume(throwing: e)
                @unknown default:
                    continuation.resume(throwing: NioUnknownContinuationSwitchError(value: resp))
                }
            })
        }
    }
    //func event(withEventId: eventId.id, inRoom: <#T##String#>, completion: <#T##(MXResponse<MXEvent>) -> Void#>)
    
}
