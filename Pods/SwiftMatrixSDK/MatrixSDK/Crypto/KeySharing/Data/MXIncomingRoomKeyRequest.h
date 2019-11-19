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

/**
 `MXIncomingRoomKeyRequest` represents a received m.room_key_request event.
 */
@interface MXIncomingRoomKeyRequest : MXJSONModel

/**
 The user requesting the key.
 */
@property (nonatomic) NSString *userId;

/**
 The device requesting the key.
 */
@property (nonatomic) NSString *deviceId;

/**
 The requestId unique id for the request.
 */
@property (nonatomic) NSString *requestId;

/**
 The parameters of a room key request. The details of the request may
 vary with the crypto algorithm, but the management and storage layers for
 outgoing requests expect it to have 'room_id' and 'session_id' properties
 */
@property (nonatomic) NSDictionary *requestBody;

/**
 Create the `MXIncomingRoomKeyRequest` object from a Matrix m.room_key_request event.

 @param event The m.room_key_request event.
 */
- (instancetype)initWithMXEvent:(MXEvent*)event;

@end
