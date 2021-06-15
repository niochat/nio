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
}
