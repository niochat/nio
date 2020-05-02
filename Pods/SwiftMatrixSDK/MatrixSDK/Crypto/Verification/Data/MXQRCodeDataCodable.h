/*
 Copyright 2020 The Matrix.org Foundation C.I.C
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 QR code verification modes
 */
typedef NS_ENUM(NSUInteger, MXQRCodeVerificationMode) {
    MXQRCodeVerificationModeVerifyingAnotherUser = 0,          // verifying another user with cross-signing
    MXQRCodeVerificationModeSelfVerifyingMasterKeyTrusted,     // self-verifying in which the current device does trust the master key
    MXQRCodeVerificationModeSelfVerifyingMasterKeyNotTrusted   // self-verifying in which the current device does not yet trust the master key
};

/**
 `MXQRCodeDataCodable` represents QR code format as described by
 [MSC1543](https://github.com/uhoreg/matrix-doc/blob/qr_key_verification/proposals/1543-qr_code_key_verification.md#qr-code-format).
 */
@protocol MXQRCodeDataCodable <NSObject>

// the QR code version
@property (nonatomic, readonly) NSUInteger version;

// the QR code verification mode
@property (nonatomic, readonly) MXQRCodeVerificationMode verificationMode;

// the event ID or transaction id of the associated verification request event
@property (nonatomic, strong, readonly) NSString *transactionId;

// the first key, as 32 bytes. The key to use depends on the verification mode
@property (nonatomic, strong, readonly) NSString *firstKey;

// the second key, as 32 bytes. The key to use depends on the verification mode
@property (nonatomic, strong, readonly) NSString *secondKey;

// random shared secret
@property (nonatomic, strong, readonly) NSData *sharedSecret;

@end

NS_ASSUME_NONNULL_END
