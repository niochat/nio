//
//  MXAutoDiscovery+Async.swift
//  Masui
//
//  Created by Finn Behrens on 11.06.21.
//

import Foundation
import MatrixSDK

public extension MXAutoDiscovery {
    func findClientConfig() async throws -> MXDiscoveredClientConfig {
        try await withCheckedThrowingContinuation { continuation in
            self.findClientConfig({ continuation.resume(returning: $0) }, failure: { continuation.resume(throwing: $0) })
        }
    }
}
