//
//  MXRoom+Asnyc.swift
//  Masui
//
//  Created by Finn Behrens on 11.06.21.
//

import Foundation
import MatrixSDK

extension MXRoom {
    func members() async throws -> MXRoomMembers? {
        return try await withCheckedThrowingContinuation {continuation in
            self.members(completion: {resp in
                switch resp {
                case .success(let v):
                    continuation.resume(returning: v)
                case .failure(let e):
                    continuation.resume(throwing: e)
                @unknown default:
                    continuation.resume(throwing: NioUnknownContinuationSwitchError(value: resp))
                }
            })
        }
    }
}
