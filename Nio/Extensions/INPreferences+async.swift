//
//  INPreferences+async.swift
//  Nio
//
//  Created by Finn Behrens on 25.06.21.
//  Copyright © 2021 Kilian Koeltzsch. All rights reserved.
//

import Foundation
import Intents

extension INPreferences {
    @discardableResult
    public static func requestSiriAuthorization()  async -> INSiriAuthorizationStatus {
        return await withCheckedContinuation { continuation in
            INPreferences.requestSiriAuthorization({ continuation.resume(returning: $0) })
        }
    }
}
