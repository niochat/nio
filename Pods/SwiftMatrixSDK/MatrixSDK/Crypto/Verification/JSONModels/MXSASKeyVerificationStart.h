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

#import "MXKeyVerificationStart.h"

NS_ASSUME_NONNULL_BEGIN

@interface MXSASKeyVerificationStart : MXKeyVerificationStart

/**
 An array of key agreement protocols that Alice’s client understands.
 Must include “curve25519”.
 Other methods may be defined in the future.
 */
@property (nonatomic, nullable) NSArray<NSString*> *keyAgreementProtocols;

/**
 Sn array of hashes that Alice’s client understands.
 Must include “sha256”. Other methods may be defined in the future.
 */
@property (nonatomic, nullable) NSArray<NSString*> *hashAlgorithms;

/**
 An array of message authentication codes that Alice’s client understands.
 Must include “hmac-sha256”. Other methods may be defined in the future.
 */
@property (nonatomic, nullable) NSArray<NSString*> *messageAuthenticationCodes;

/**
 An array of short authentication string methods that Alice’s client (and Alice) understands.
 Must include “decimal”. This document also describes the “emoji” method.
 Other methods may be defined in the future.
 */
@property (nonatomic, nullable) NSArray<NSString*> *shortAuthenticationString;

@end

NS_ASSUME_NONNULL_END
