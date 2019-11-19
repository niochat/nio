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

#import "MXEvent.h"

@interface MXIncomingRoomKeyRequestCancellation : NSObject

/**
 The user requesting the cancellation.
 */
@property (nonatomic, readonly) NSString *userId;

/**
 The device requesting the cancellation.
 */
@property (nonatomic, readonly) NSString *deviceId;

/**
 The unique id for the request to be cancelled.
 */
@property (nonatomic, readonly) NSString *requestId;

/**
 Create the `MXIncomingRoomKeyRequestCancellation` object from a Matrix m.room_key_request event.

 @param event The m.room_key_request event.
 */
- (instancetype)initWithMXEvent:(MXEvent*)event;

@end
