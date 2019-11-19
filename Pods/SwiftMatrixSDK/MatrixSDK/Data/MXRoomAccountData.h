/*
 Copyright 2015 OpenMarket Ltd

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

#import "MXJSONModels.h"

/**
 `MXRoomAccountData` represents private data that the user has defined for a room.
 */
@interface MXRoomAccountData : NSObject <NSCoding>

/**
 The tags the user defined for this room.
 The key is the tag name. The value, the associated MXRoomTag object.
 */
@property (nonatomic, readonly) NSDictionary <NSString*, MXRoomTag*> *tags;

/**
 The event identifier which marks the last event read by the user.
 */
@property (nonatomic) NSString* readMarkerEventId;

/**
 Process an event that modifies room account data (like m.tag event).

 @param event an event
 */
- (void)handleEvent:(MXEvent*)event;

@end
