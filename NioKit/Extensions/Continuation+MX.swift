//
//  Continuation+MX.swift
//  Continuation+MX
//
//  Created by Finn Behrens on 05.08.21.
//  Copyright © 2021 Kilian Koeltzsch. All rights reserved.
//

import Foundation
import MatrixSDK

extension CheckedContinuation {
    public func resume(with mxResult: MXResponse<T>) {
        switch mxResult {
        case .success(let v): self.resume(returning: v)
        case .failure(let e): self.resume(throwing: e as! E)
        @unknown default:
            self.resume(throwing: NioUnknownContinuationSwitchError(value: mxResult) as! E)
        }
    }
}


struct NioUnknownContinuationSwitchError: Error {
     let value: Any
 }
