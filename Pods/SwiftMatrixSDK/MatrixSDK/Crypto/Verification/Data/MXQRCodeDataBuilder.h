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

#import "MXVerifyingAnotherUserQRCodeData.h"
#import "MXSelfVerifyingMasterKeyTrustedQRCodeData.h"
#import "MXSelfVerifyingMasterKeyNotTrustedQRCodeData.h"

NS_ASSUME_NONNULL_BEGIN

@interface MXQRCodeDataBuilder : NSObject

/**
 Create approriate MXQRCodeData subclass based on verificationMode parameter.

 @param verificationMode The QR code verification mode.
 @param transactionId The event id or transaction id of the associated verification request event.
 @param firstKey The key to use depends on the verification mode as unpadded base 64 string.
 @param secondKey The key to use depends on the verification mode as unpadded base 64 string.
 @param sharedSecret A random shared secret as base 64 data padded.
 @return Approriate MXQRCodeData subclass based on verifciationMode parameter.
 */
- (nullable MXQRCodeData*)buildQRCodeDataWithVerificationMode:(MXQRCodeVerificationMode)verificationMode
                                                transactionId:(NSString*)transactionId
                                                     firstKey:(NSString*)firstKey
                                                    secondKey:(NSString*)secondKey
                                                 sharedSecret:(NSData*)sharedSecret;

/**
 Create QR code format specialized class used for MXQRCodeVerificationModeVerifyingAnotherUser verification mode.

 @param transactionId The event id or transaction id of the associated verification request event.
 @param userCrossSigningMasterKeyPublic The user's own master cross-signing public key as unpadded base 64 string.
 @param otherUserCrossSigningMasterKeyPublic Other user master cross-signing public key as unpadded base 64 string.
 @return MXVerifyingAnotherUserQRCodeData instance or nil if parameters are not valid.
 */
- (nullable MXVerifyingAnotherUserQRCodeData*)buildVerifyingAnotherUserQRCodeDataWithTransactionId:(NSString*)transactionId
                                                                   userCrossSigningMasterKeyPublic:(NSString*)userCrossSigningMasterKeyPublic
                                                              otherUserCrossSigningMasterKeyPublic:(NSString*)otherUserCrossSigningMasterKeyPublic;

/**
 Create QR code format specialized class used for MXQRCodeVerificationModeSelfVerifyingMasterKeyTrusted verification mode.

 @param transactionId The event id or transaction id of the associated verification request event.
 @param userCrossSigningMasterKeyPublic The user's own master cross-signing public key as unpadded base 64 string.
 @param otherDeviceKey The other device's device key as unpadded base 64 string.
 @return MXSelfVerifyingMasterKeyTrustedQRCodeData instance or nil if parameters are not valid.
 */
- (nullable MXSelfVerifyingMasterKeyTrustedQRCodeData*)buildSelfVerifyingMasterKeyTrustedQRCodeDataWithTransactionId:(NSString*)transactionId
                                                                                     userCrossSigningMasterKeyPublic:(NSString*)userCrossSigningMasterKeyPublic
                                                                                                      otherDeviceKey:(NSString*)otherDeviceKey;

/**
 Create QR code format specialized class used for MXQRCodeVerificationModeSelfVerifyingMasterKeyNotTrusted verification mode.

 @param transactionId The event id or transaction id of the associated verification request event.
 @param currentDeviceKey The current device's device key as unpadded base 64 string.
 @param userCrossSigningMasterKeyPublic user's master cross-signing key as unpadded base 64 string.
 @return MXSelfVerifyingMasterKeyNotTrustedQRCodeData instance or nil if parameters are not valid.
 */
- (nullable MXSelfVerifyingMasterKeyNotTrustedQRCodeData*)buildSelfVerifyingMasterKeyNotTrustedQRCodeDataWithTransactionId:(NSString*)transactionId
                                                                                                       currentDeviceKey:(NSString*)currentDeviceKey
                                                                                        userCrossSigningMasterKeyPublic:(NSString*)userCrossSigningMasterKeyPublic;

/**
 Generate a random shared secret data

 @return A random shared secret padded base64 data.
 */
- (NSData*)generateSharedSecret;

@end

NS_ASSUME_NONNULL_END
