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

#import <Foundation/Foundation.h>
#import "MXJSONModel.h"

/**
 A `MXRoomTombStoneContent` instance represents the content of a `m.room.tombstone` event type.
 */
@interface MXRoomTombStoneContent : MXJSONModel

/**
 The reason message for the obsolence of the room.
 */
@property (nonatomic, copy, readonly, nonnull) NSString *body;

/**
 The identifier of the room that comes in replacement.
 */
@property (nonatomic, copy, readonly, nonnull) NSString *replacementRoomId;

@end
