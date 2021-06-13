//
//  MXAutoDiscovery+Async.swift
//  Masui
//
//  Created by Finn Behrens on 11.06.21.
//

import Foundation
import MatrixSDK

extension MXAutoDiscovery {
    public func findClientConfig() async throws -> MXDiscoveredClientConfig {
        return try await withCheckedThrowingContinuation {continuation in
            self.findClientConfig({ continuation.resume(returning: $0)}, failure: {continuation.resume(throwing: $0)})
        }
    }
}
