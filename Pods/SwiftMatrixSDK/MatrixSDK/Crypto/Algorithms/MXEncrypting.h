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

#import "MXHTTPOperation.h"
#import "MXEvent.h"
#import "MXDeviceInfo.h"

@class MXCrypto;

@protocol MXEncrypting <NSObject>

/**
 Constructor.

 @param crypto the related 'MXCrypto'.
 @param roomId the id of the room we will be sending to.
 */
- (instancetype)initWithCrypto:(MXCrypto*)crypto andRoom:(NSString*)roomId;

/**
 Encrypt an event content according to the configuration of the room.

 @param eventContent the content of the event.
 @param eventType the type of the event.
 @param users the room members the event will be sent to.

 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance. May be nil if all required materials is already in place.
 */
- (MXHTTPOperation*)encryptEventContent:(NSDictionary*)eventContent eventType:(MXEventTypeString)eventType
                               forUsers:(NSArray<NSString*>*)users
                                success:(void (^)(NSDictionary *encryptedContent))success
                                failure:(void (^)(NSError *error))failure;

/**
 Ensure the set up of the session.
 
 @param users the room members events will be sent to.

 @param success A block object called when the operation succeeds. 
                sessionInfo is an internal object, specific to the algorithm.
 @param failure A block object called when the operation fails.

 @return a MXHTTPOperation instance. May be nil if all required materials is already in place.
 */
- (MXHTTPOperation*)ensureSessionForUsers:(NSArray<NSString*>*)users
                                  success:(void (^)(NSObject *sessionInfo))success
                                  failure:(void (^)(NSError *error))failure;

/**
 Re-shares a session key with devices if the key has already been
 sent to them.
 
 @param sessionId The id of the outbound session to share.
 @param userId The id of the user who owns the target device.
 @param deviceId he id of the target device.
 @param senderKey The key of the originating device for the session.

 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.
 
 @return a MXHTTPOperation instance.
 */
- (MXHTTPOperation*)reshareKey:(NSString*)sessionId
                      withUser:(NSString*)userId
                     andDevice:(NSString*)deviceId
                     senderKey:(NSString*)senderKey
                       success:(void (^)(void))success
                       failure:(void (^)(NSError *error))failure;

@end
