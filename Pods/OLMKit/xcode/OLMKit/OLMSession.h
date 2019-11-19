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
#import "OLMAccount.h"
#import "OLMMessage.h"

@interface OLMSession : NSObject <OLMSerializable, NSSecureCoding>

- (instancetype) initOutboundSessionWithAccount:(OLMAccount*)account theirIdentityKey:(NSString*)theirIdentityKey theirOneTimeKey:(NSString*)theirOneTimeKey error:(NSError**)error;

- (instancetype) initInboundSessionWithAccount:(OLMAccount*)account oneTimeKeyMessage:(NSString*)oneTimeKeyMessage error:(NSError**)error;

- (instancetype) initInboundSessionWithAccount:(OLMAccount*)account theirIdentityKey:(NSString*)theirIdentityKey oneTimeKeyMessage:(NSString*)oneTimeKeyMessage error:(NSError**)error;

- (NSString*) sessionIdentifier;

- (BOOL) matchesInboundSession:(NSString*)oneTimeKeyMessage;

- (BOOL) matchesInboundSessionFrom:(NSString*)theirIdentityKey oneTimeKeyMessage:(NSString *)oneTimeKeyMessage;

/** UTF-8 plaintext -> base64 ciphertext */
- (OLMMessage*) encryptMessage:(NSString*)message error:(NSError**)error;

/** base64 ciphertext -> UTF-8 plaintext */
- (NSString*) decryptMessage:(OLMMessage*)message error:(NSError**)error;

@end
