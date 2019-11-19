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

#pragma mark - Defines & Constants

static NSString* const kRoomPredecessorRoomIdJSONKey = @"room_id";
static NSString* const kRoomPredecessorTombstoneEventIdJSONKey = @"event_id";

#pragma mark - Private Interface

@interface MXRoomPredecessorInfo()

@property (nonatomic, copy, readwrite, nonnull) NSString *roomId;
@property (nonatomic, copy, readwrite, nonnull) NSString *tombStoneEventId;

@end

@implementation MXRoomPredecessorInfo

#pragma mark - MXJSONModel

+ (id)modelFromJSON:(NSDictionary *)jsonDictionary
{
    MXRoomPredecessorInfo *tombStoneContent = nil;
    
    NSString *roomId;
    NSString *tombStoneEventId;
    
    MXJSONModelSetString(roomId, jsonDictionary[kRoomPredecessorRoomIdJSONKey]);
    MXJSONModelSetString(tombStoneEventId, jsonDictionary[kRoomPredecessorTombstoneEventIdJSONKey]);
    
    if (roomId && tombStoneEventId)
    {
        tombStoneContent = [MXRoomPredecessorInfo new];
        tombStoneContent.roomId = roomId;
        tombStoneContent.tombStoneEventId = tombStoneEventId;
    }
    
    return tombStoneContent;
}

- (NSDictionary *)JSONDictionary
{
    NSMutableDictionary *jsonDictionary = [NSMutableDictionary dictionary];
    
    jsonDictionary[kRoomPredecessorRoomIdJSONKey] = self.roomId;
    jsonDictionary[kRoomPredecessorTombstoneEventIdJSONKey] = self.tombStoneEventId;
    
    return jsonDictionary;
}

@end
