/*
 Copyright 2016 OpenMarket Ltd

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

#import "MXSDKOptions.h"

#ifdef MX_CRYPTO

#import <OLMKit/OLMKit.h>

#import "MXMegolmSessionData.h"

/**
 The 'MXOlmInboundGroupSession' class adds more context to a OLMInboundGroupSession
 object from OLMKit.
 
 This allows additional checks.
 The class implements NSCoding so that OLMInboundGroupSession can be stored with its
 context.
 */
@interface MXOlmInboundGroupSession : NSObject <NSCoding>

/**
 Initialise the underneath olm inbound group session.
 
 @param sessionKey the session key.
 */
- (instancetype)initWithSessionKey:(NSString*)sessionKey;

/**
 The associated olm inbound group session.
 */
@property (nonatomic, readonly) OLMInboundGroupSession *session;

/**
 The room in which this session is used.
 */
@property (nonatomic) NSString *roomId;

/**
 The base64-encoded curve25519 key of the sender.
 */
@property (nonatomic) NSString *senderKey;

/**
 Devices which forwarded this session to us.
 */
@property NSArray<NSString *> *forwardingCurve25519KeyChain;

/**
 Other keys the sender claims.
 */
@property (nonatomic) NSDictionary<NSString*, NSString*> *keysClaimed;


#pragma mark - import/export

/**
 Export the session data from a given message.
 
 @param messageIndex the index of message from which to export the session.
 @return the exported data.
 */
- (MXMegolmSessionData *)exportSessionDataAtMessageIndex:(NSUInteger)messageIndex;

/**
 Export the session data from the first known message.

 @return the exported data.
 */
- (MXMegolmSessionData *)exportSessionData;

- (instancetype)initWithImportedSessionData:(MXMegolmSessionData*)data;
- (instancetype)initWithImportedSessionKey:(NSString*)sessionKey;

@end

#endif // MX_CRYPTO
