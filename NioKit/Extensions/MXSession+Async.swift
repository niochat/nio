//
//  MXSession+Async.swift
//  MXSession Async Extension
//
//  Created by Finn Behrens on 05.08.21.
//  Copyright © 2021 Kilian Koeltzsch. All rights reserved.
//

import Foundation
import MatrixSDK

extension MXSession {
    public func logout() async throws {
        return try await withCheckedThrowingContinuation {continuation in
            self.logout(completion: { continuation.resume(with: $0) })
        }
    }
    
    public func setStore(_ store: MXStore) async throws {
        return try await withCheckedThrowingContinuation {continuation in
            self.setStore(store, completion: { continuation.resume(with: $0) })
        }
    }
    
    public func start(withSyncFilterId filterId: String? = nil) async throws {
        return try await withCheckedThrowingContinuation {continuation in
            self.start(withSyncFilterId: filterId, completion: { continuation.resume(with: $0) })
        }
    }
}
