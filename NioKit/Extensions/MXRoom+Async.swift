//
//  MXRoom+Async.swift
//  MXRoom+Async
//
//  Created by Finn Behrens on 05.08.21.
//  Copyright © 2021 Kilian Koeltzsch. All rights reserved.
//

import Foundation
import MatrixSDK

extension MXRoom {
    func members() async throws -> MXRoomMembers? {
        return try await withCheckedThrowingContinuation {continuation in
            self.members(completion: { continuation.resume(with: $0) })
        }
    }
}
