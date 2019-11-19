/*
 Copyright 2018 New Vector Ltd

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

#import "MXJSONModel.h"

NS_ASSUME_NONNULL_BEGIN

/**
 Data model for MXKeyBackupVersion.authData in case of kMXCryptoMegolmBackupAlgorithm.
 */
@interface MXMegolmBackupAuthData : MXJSONModel

/**
 The curve25519 public key used to encrypt the backups.
 */
@property (nonatomic) NSString *publicKey;

/**
 In case of a backup created from a password, the salt associated with the backup
 private key.
 */
@property (nonatomic, nullable) NSString *privateKeySalt;

/**
 In case of a backup created from a password, the number of key derivations.
 */
@property (nonatomic) NSUInteger privateKeyIterations;

/**
 Signatures of the public key.
 userId -> (deviceSignKeyId -> signature)
 */
@property (nonatomic) NSDictionary<NSString*, NSDictionary*> *signatures;

/**
 Same as the parent [MXJSONModel JSONDictionary] but return only
 data that must be signed.
 */
@property (nonatomic, readonly) NSDictionary *signalableJSONDictionary;

@end

NS_ASSUME_NONNULL_END
