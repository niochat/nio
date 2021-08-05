//
//  MXAutoDiscovery+Async.swift
//  MXAutoDiscovery+Async
//
//  Created by Finn Behrens on 05.08.21.
//  Copyright © 2021 Kilian Koeltzsch. All rights reserved.
//

import Foundation
import MatrixSDK

extension MXAutoDiscovery {
    public func findClientConfig() async throws -> MXDiscoveredClientConfig {
        return try await withCheckedThrowingContinuation {continuation in
            self.findClientConfig({continuation.resume(returning: $0)}, failure: {continuation.resume(throwing: $0)})
        }
    }
}
