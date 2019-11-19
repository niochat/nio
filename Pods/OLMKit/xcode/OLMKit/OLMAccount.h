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
#import "OLMSerializable.h"

@class OLMSession;

@interface OLMAccount : NSObject <OLMSerializable, NSSecureCoding>

/** Creates new account */
- (instancetype) initNewAccount;

/** public identity keys. base64 encoded in "curve25519" and "ed25519" keys */
- (NSDictionary*) identityKeys;

/** signs message with ed25519 key for account */
- (NSString*) signMessage:(NSData*)messageData;

/** Public parts of the unpublished one time keys for the account */
- (NSDictionary*) oneTimeKeys;

- (BOOL) removeOneTimeKeysForSession:(OLMSession*)session;

/** Marks the current set of one time keys as being published. */
- (void) markOneTimeKeysAsPublished;

/** The largest number of one time keys this account can store. */
- (NSUInteger) maxOneTimeKeys;

/** Generates a number of new one time keys. If the total number of keys stored
 * by this account exceeds -maxOneTimeKeys then the old keys are
 * discarded. */
- (void) generateOneTimeKeys:(NSUInteger)numberOfKeys;

@end
