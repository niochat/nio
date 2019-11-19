/*
 Copyright 2017 OpenMarket Ltd

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

#import "MXUsersDevicesMap.h"
#import "MXIncomingRoomKeyRequest.h"
#import "MXIncomingRoomKeyRequestCancellation.h"

#import "MXSDKOptions.h"

#ifdef MX_CRYPTO

@class MXCrypto;

/**
 A `MXKKeyRequestManager` object gathers incoming key requests from the attached
 Matrix session.
 It then sorts them by user/device pairs so that when the user accept to share keys
 with a user's device, all pending incoming key requests from this device will be
 accepted.
 */
@interface MXIncomingRoomKeyRequestManager : NSObject

/**
 Constructor.

 @param crypto the related `MXCrypto`.
 @return the newly created `MXIncomingRoomKeyRequestManager` instance.
 */
- (instancetype)initWithCrypto:(MXCrypto*)crypto;

/**
 Stop the incoming key request manager.
 */
- (void)close;

/**
 Called when we get an m.room_key_request event.

 @param event the key request event.
 */
- (void)onRoomKeyRequestEvent:(MXEvent*)event;

/**
 Process any m.room_key_request events which were queued up during the
 current sync.
 */
- (void)processReceivedRoomKeyRequests;

/**
 Remove the pending key request matching given ids.
 */
- (void)removePendingKeyRequest:(NSString*)requestId fromUser:(NSString*)userId andDevice:(NSString*)deviceId;

/**
 Pending key requests at the last sync computing completion.
 userId -> deviceId -> [keyRequest]
 */
@property (nonatomic, readonly) MXUsersDevicesMap<NSArray<MXIncomingRoomKeyRequest *> *> *pendingKeyRequests;

@end

#endif

