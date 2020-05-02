/*
 Copyright 2019 The Matrix.org Foundation C.I.C

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

#import "MXJSONModel.h"

#import "MXUsersDevicesMap.h"

NS_ASSUME_NONNULL_BEGIN


#pragma mark - Constants

//! Cross-signing key types
extern const struct MXCrossSigningKeyType {
    __unsafe_unretained NSString *master;
    __unsafe_unretained NSString *selfSigning;
    __unsafe_unretained NSString *userSigning;
} MXCrossSigningKeyType;


/**
 `MXCrossSigningKey` represents keys object as described by
 [MSC1756](https://github.com/uhoreg/matrix-doc/blob/cross-signing2/proposals/1756-cross-signing.md ).
 */
@interface MXCrossSigningKey : MXJSONModel

/**
 The user who owns the key.
 */
@property (nonatomic, readonly) NSString *userId;

/**
 Allowed uses for the key.

 */
@property (nonatomic, readonly) NSArray<NSString*> *usage;

/**
 The unpadded base64 encoding of the public key.
 */
@property (nonatomic, readonly) NSString *keys;

/**
 Signatures by userId by public key.
 MXUsersDevicesMap is abused here. Public keys replace device ids.
 */
@property (nonatomic, readonly, nullable) MXUsersDevicesMap<NSString*> *signatures;


- (instancetype)initWithUserId:(NSString*)userId usage:(NSArray<NSString*>*)usage keys:(NSString*)keys;

- (void)addSignatureFromUserId:(NSString*)userId publicKey:(NSString*)publicKey signature:(NSString*)signature;
- (nullable NSString*)signatureFromUserId:(NSString*)userId withPublicKey:(NSString*)publicKey;

/**
 Same as the parent [MXJSONModel JSONDictionary] but return only data that must
 be signed.
 */
- (NSDictionary*)signalableJSONDictionary;

@end

NS_ASSUME_NONNULL_END
