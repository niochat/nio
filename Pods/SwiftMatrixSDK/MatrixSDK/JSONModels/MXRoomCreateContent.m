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

#import "MXRoomCreateContent.h"

#pragma mark - Defines & Constants

static NSString* const kRoomCreateContentUserIdJSONKey = @"creator";
static NSString* const kRoomCreateContentPredecessorInfoJSONKey = @"predecessor";
static NSString* const kRoomCreateContentRoomVersionJSONKey = @"room_version";
static NSString* const kRoomCreateContentFederateJSONKey = @"m.federate";

#pragma mark - Private Interface

@interface MXRoomCreateContent()

@property (nonatomic, copy, readwrite, nullable) NSString *creatorUserId;
@property (nonatomic, strong, readwrite, nullable) MXRoomPredecessorInfo *roomPredecessorInfo;
@property (nonatomic, copy, readwrite, nullable) NSString *roomVersion;
@property (nonatomic, readwrite) BOOL isFederated;

@end

@implementation MXRoomCreateContent

+ (id)modelFromJSON:(NSDictionary *)jsonDictionary
{
    MXRoomCreateContent *roomCreateContent = [MXRoomCreateContent new];
    if (roomCreateContent)
    {
        // Set the isFederated flag to true (default value).
        roomCreateContent.isFederated = YES;
        
        MXJSONModelSetString(roomCreateContent.creatorUserId, jsonDictionary[kRoomCreateContentUserIdJSONKey]);
        MXJSONModelSetMXJSONModel(roomCreateContent.roomPredecessorInfo, MXRoomPredecessorInfo, jsonDictionary[kRoomCreateContentPredecessorInfoJSONKey]);
        MXJSONModelSetString(roomCreateContent.roomVersion, jsonDictionary[kRoomCreateContentRoomVersionJSONKey]);
        MXJSONModelSetBoolean(roomCreateContent.isFederated, jsonDictionary[kRoomCreateContentFederateJSONKey])
    }
    
    return roomCreateContent;
}

- (NSDictionary *)JSONDictionary
{
    NSMutableDictionary *jsonDictionary = [NSMutableDictionary dictionary];
    
    if (self.creatorUserId)
    {
        jsonDictionary[kRoomCreateContentUserIdJSONKey] = self.creatorUserId;
    }
    
    if (self.roomPredecessorInfo)
    {
        jsonDictionary[kRoomCreateContentPredecessorInfoJSONKey] = [self.roomPredecessorInfo JSONDictionary];
    }
    
    if (self.roomVersion)
    {
        jsonDictionary[kRoomCreateContentRoomVersionJSONKey] = self.roomVersion;
    }
    
    jsonDictionary[kRoomCreateContentFederateJSONKey] = @(self.isFederated);
    
    return jsonDictionary;
}

@end
