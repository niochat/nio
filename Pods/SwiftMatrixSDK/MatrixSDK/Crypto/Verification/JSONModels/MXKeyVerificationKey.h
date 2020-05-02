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
 Sent by both devices to send their ephemeral Curve25519 public key the other device.
 */
@interface MXKeyVerificationKey : MXKeyVerificationJSONModel

/**
 The device’s ephemeral public key, as an unpadded base64 string.
 */
@property (nonatomic, nullable) NSString *key;


/**
 Check content validity.

 @return YES if valid.
 */
- (BOOL)isValid;

@end

NS_ASSUME_NONNULL_END
