//
//  MXRestClient+Async.swift
//  MXRestClient+Async
//
//  Created by Finn Behrens on 05.08.21.
//  Copyright © 2021 Kilian Koeltzsch. All rights reserved.
//

import Foundation
import MatrixSDK

extension MXRestClient {
    func login(type loginType: MXLoginFlowType = .password, username: String, password: String) async throws -> MXCredentials {
        return try await withCheckedThrowingContinuation {continuation in
            self.login(type: loginType, username: username, password: password, completion: { continuation.resume(with: $0) })
        }
    }
    func wellKnown() async throws -> MXWellKnown {
        return try await withCheckedThrowingContinuation {continuation in
            self.wellKnow({continuation.resume(returning: $0!)}, failure: {continuation.resume(throwing: $0!)})
        }
    }
}
