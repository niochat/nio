/*
 Copyright 2016 Chris Ballinger
 Copyright 2016 OpenMarket Ltd
 Copyright 2016 Vector Creations Ltd

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

FOUNDATION_EXPORT NSString *const OLMErrorDomain;

@interface OLMUtility : NSObject

/**
 Calculate the SHA-256 hash of the input and encodes it as base64.
 
 @param message the message to hash.
 @return the base64-encoded hash value.
 */
- (NSString*)sha256:(NSData*)message;

/**
 Verify an ed25519 signature.

 @param signature the base64-encoded signature to be checked.
 @param key the ed25519 key.
 @param message the message which was signed.
 @param error if there is a problem with the verification.
 If the key was too small then the message will be "OLM.INVALID_BASE64".
 If the signature was invalid then the message will be "OLM.BAD_MESSAGE_MAC".

 @return YES if valid.
 */
- (BOOL)verifyEd25519Signature:(NSString*)signature key:(NSString*)key message:(NSData*)message error:(NSError**)error;

+ (NSMutableData*) randomBytesOfLength:(NSUInteger)length;

@end
