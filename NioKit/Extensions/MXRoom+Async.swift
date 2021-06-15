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
        try await withCheckedThrowingContinuation { continuation in
            self.members(completion: { resp in
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

    var liveTimeline: MXEventTimeline {
        get async {
            await withCheckedContinuation { continuation in
                self.liveTimeline { continuation.resume(returning: $0!) }
            }
        }
    }
}
