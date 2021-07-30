//
//  MXMediaManager+Async.swift
//  Nio
//
//  Created by Finn Behrens on 25.06.21.
//  Copyright © 2021 Kilian Koeltzsch. All rights reserved.
//

import Foundation
import MatrixSDK

extension MXMediaManager {
    
    /**
     Download encrypted data from the Matrix Content repository.
     
     @param encryptedContentFile the encrypted Matrix Content details.
     @param folder the cache folder to use (may be nil). kMXMediaManagerDefaultCacheFolder is used by default.
     @return the path of the resulting file.
     */
    public func downloadEncryptedMedia(fromMatrixContentFile contentFile: MXEncryptedContentFile, inFolder folder: String?) async throws -> String {
        return try await withCheckedThrowingContinuation {continuation in
            self.downloadEncryptedMedia(fromMatrixContentFile: contentFile, inFolder: folder, success: {value in continuation.resume(returning: value!)}, failure: {e in continuation.resume(throwing: e!)})
        }
    }
}
