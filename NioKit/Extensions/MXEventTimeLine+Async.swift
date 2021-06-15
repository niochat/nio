//
//  MXEventTimeLine+Async.swift
//  Nio
//
//  Created by Finn Behrens on 15.06.21.
//  Copyright © 2021 Kilian Koeltzsch. All rights reserved.
//

import Foundation
import MatrixSDK

extension MXEventTimeline {
    func paginate(_ numItems: UInt, direction: MXTimelineDirection = .backwards, onlyFromStore: Bool = false) async throws {
        return try await withCheckedThrowingContinuation {continuation in
            self.paginate(numItems, direction: direction, onlyFromStore: onlyFromStore, completion: {resp in
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
}
