/*
 Copyright 2018 New Vector Ltd
 
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

#import "MXRoomPredecessorInfo.h"

/**
 A `MXRoomCreateContent` instance represents the content of a `m.room.create` event type.
 */
@interface MXRoomCreateContent : MXJSONModel

/**
 The `user_id` of the room creator. This is set by the homeserver.
 */
@property (nonatomic, copy, readonly, nullable) NSString *creatorUserId;

/**
 Room predecessor information if the current room is a new version of an old room (that has a state event `m.room.tombstone`).
 */
@property (nonatomic, strong, readonly, nullable) MXRoomPredecessorInfo *roomPredecessorInfo;

/**
 The version of the room.
 */
@property (nonatomic, copy, readonly, nullable) NSString *roomVersion;

/**
 Whether users on other servers can join this room.
 */
@property (nonatomic, readonly) BOOL isFederated;

@end
