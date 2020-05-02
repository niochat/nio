/*
 Copyright 2019 New Vector Ltd

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

#import "MXKeyVerificationJSONModel.h"

NS_ASSUME_NONNULL_BEGIN

/**
 Sent by Bob to accept a verification from a previously sent m.key.verification.start message.
 */
@interface MXKeyVerificationAccept : MXKeyVerificationJSONModel

/**
 The key agreement protocol that Bob’s device has selected to use,
 out of the list proposed by Alice’s device.
 */
@property (nonatomic, nullable) NSString *keyAgreementProtocol;

/**
 The hash algorithm that Bob’s device has selected to use, out of the list proposed
 by Alice’s device.
 */
@property (nonatomic, nullable) NSString *hashAlgorithm;

/**
 The message authentication code that Bob’s device has selected to use,
 out of the list proposed by Alice’s device
 */
@property (nonatomic, nullable) NSString *messageAuthenticationCode;

/**
 An array of short authentication string methods that Bob’s client (and Bob) understands.
 Must be a subset of the list proposed by Alice’s device.
 */
@property (nonatomic, nullable) NSArray<NSString*> *shortAuthenticationString;

/**
 The hash (encoded as unpadded base64) of the concatenation of the device’s ephemeral
 public key (QB, encoded as unpadded base64) and the canonical JSON representation of
 the m.key.verification.start message.
 */
@property (nonatomic, nullable) NSString *commitment;


/**
 Check content validity.

 @return YES if valid.
 */
- (BOOL)isValid;

@end

NS_ASSUME_NONNULL_END
