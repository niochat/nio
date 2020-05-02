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

#import "MXQRCodeDataBuilder.h"

#import "MXBase64Tools.h"

static NSUInteger const kKeyBytesCount = 32;
static NSUInteger const kSharedSecretBytesCount = 8;

@implementation MXQRCodeDataBuilder

#pragma mark - Public

- (MXQRCodeData*)buildQRCodeDataWithVerificationMode:(MXQRCodeVerificationMode)verificationMode
                                       transactionId:(NSString*)transactionId
                                            firstKey:(NSString*)firstKey
                                           secondKey:(NSString*)secondKey
                                        sharedSecret:(NSData*)sharedSecret
{
    if (![self isKeyValid:firstKey])
    {
        NSLog(@"[MXQRCodeDataBuilder] buildQRCodeDataWithVerificationMode, First key is invalid");
        return nil;
    }
    
    if (![self isKeyValid:secondKey])
    {
        NSLog(@"[MXQRCodeDataBuilder] buildQRCodeDataWithVerificationMode, Second key is invalid");
        return nil;
    }
    
    if (![self isSharedSecretValid:sharedSecret])
    {
        NSLog(@"[MXQRCodeDataBuilder] buildQRCodeDataWithVerificationMode, Shared secret is invalid");
        return nil;
    }
    
    MXQRCodeData *qrCodeData;
    
    switch (verificationMode)
    {
        case MXQRCodeVerificationModeVerifyingAnotherUser:
            qrCodeData = [MXVerifyingAnotherUserQRCodeData new];
            break;
        case MXQRCodeVerificationModeSelfVerifyingMasterKeyTrusted:
            qrCodeData = [MXSelfVerifyingMasterKeyTrustedQRCodeData new];
            break;
        case MXQRCodeVerificationModeSelfVerifyingMasterKeyNotTrusted:
            qrCodeData = [MXSelfVerifyingMasterKeyNotTrustedQRCodeData new];
            break;
        default:
            break;
    }
    
    qrCodeData.transactionId = transactionId;
    qrCodeData.firstKey = firstKey;
    qrCodeData.secondKey = secondKey;
    qrCodeData.sharedSecret = sharedSecret;
    
    return qrCodeData;
}

- (MXVerifyingAnotherUserQRCodeData*)buildVerifyingAnotherUserQRCodeDataWithTransactionId:(NSString*)transactionId
                                                          userCrossSigningMasterKeyPublic:(NSString*)userCrossSigningMasterKeyPublic
                                                     otherUserCrossSigningMasterKeyPublic:(NSString*)otherUserCrossSigningMasterKeyPublic
{
    return (MXVerifyingAnotherUserQRCodeData*)[self buildQRCodeDataWithVerificationMode:MXQRCodeVerificationModeVerifyingAnotherUser
                                                                          transactionId:transactionId
                                                                               firstKey:userCrossSigningMasterKeyPublic
                                                                              secondKey:otherUserCrossSigningMasterKeyPublic
                                                                           sharedSecret:[self generateSharedSecret]];
}

- (MXSelfVerifyingMasterKeyTrustedQRCodeData*)buildSelfVerifyingMasterKeyTrustedQRCodeDataWithTransactionId:(NSString*)transactionId
                                                                            userCrossSigningMasterKeyPublic:(NSString*)userCrossSigningMasterKeyPublic
                                                                                             otherDeviceKey:(NSString*)otherDeviceKey
{
    return (MXSelfVerifyingMasterKeyTrustedQRCodeData*)[self buildQRCodeDataWithVerificationMode:MXQRCodeVerificationModeSelfVerifyingMasterKeyTrusted
                                                                                   transactionId:transactionId
                                                                                        firstKey:userCrossSigningMasterKeyPublic
                                                                                       secondKey:otherDeviceKey
                                                                                    sharedSecret:[self generateSharedSecret]];
}

- (nullable MXSelfVerifyingMasterKeyNotTrustedQRCodeData*)buildSelfVerifyingMasterKeyNotTrustedQRCodeDataWithTransactionId:(NSString*)transactionId
                                                                                                          currentDeviceKey:(NSString*)currentDeviceKey
                                                                                           userCrossSigningMasterKeyPublic:(NSString*)userCrossSigningMasterKeyPublic
{
    return (MXSelfVerifyingMasterKeyNotTrustedQRCodeData*)[self buildQRCodeDataWithVerificationMode:MXQRCodeVerificationModeSelfVerifyingMasterKeyNotTrusted
                                                                                      transactionId:transactionId
                                                                                           firstKey:currentDeviceKey
                                                                                          secondKey:userCrossSigningMasterKeyPublic
                                                                                       sharedSecret:[self generateSharedSecret]];
}

- (NSData*)generateSharedSecret
{
    NSMutableData *sharedSecretData = [NSMutableData dataWithLength:kSharedSecretBytesCount];
    if (SecRandomCopyBytes(kSecRandomDefault, kSharedSecretBytesCount, sharedSecretData.mutableBytes) != errSecSuccess)
    {
        return nil;
    }
    
    return sharedSecretData;
}

#pragma mark - Private

- (BOOL)isKeyValid:(NSString*)key
{
    NSData *keyData = [MXBase64Tools dataFromUnpaddedBase64:key];
    return keyData.length == kKeyBytesCount;
}

- (BOOL)isSharedSecretValid:(NSData*)sharedSecret
{
    return sharedSecret.length >= kSharedSecretBytesCount;
}


@end
