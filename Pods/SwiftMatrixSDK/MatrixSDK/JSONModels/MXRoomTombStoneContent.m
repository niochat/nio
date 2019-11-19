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

#import "MXRoomTombStoneContent.h"

#pragma mark - Defines & Constants

static NSString* const kTombStoneContentBodyJSONKey = @"body";
static NSString* const kTombStoneContentReplacementRoomIdJSONKey = @"replacement_room";

#pragma mark - Private Interface

@interface MXRoomTombStoneContent()

@property (nonatomic, copy, readwrite, nonnull) NSString *body;
@property (nonatomic, copy, readwrite, nonnull) NSString *replacementRoomId;

@end

#pragma mark - Implementation

@implementation MXRoomTombStoneContent

#pragma mark - MXJSONModel

+ (id)modelFromJSON:(NSDictionary *)jsonDictionary
{
    MXRoomTombStoneContent *tombStoneContent = nil;
    
    NSString *body;
    NSString *replacementRoomId;
    
    MXJSONModelSetString(body, jsonDictionary[kTombStoneContentBodyJSONKey]);
    MXJSONModelSetString(replacementRoomId, jsonDictionary[kTombStoneContentReplacementRoomIdJSONKey]);
    
    if (body && replacementRoomId)
    {
        tombStoneContent = [MXRoomTombStoneContent new];
        tombStoneContent.body = body;
        tombStoneContent.replacementRoomId = replacementRoomId;
    }
    
    return tombStoneContent;
}

- (NSDictionary *)JSONDictionary
{
    NSMutableDictionary *jsonDictionary = [NSMutableDictionary dictionary];
    
    jsonDictionary[kTombStoneContentBodyJSONKey] = self.body;
    jsonDictionary[kTombStoneContentReplacementRoomIdJSONKey] = self.replacementRoomId;
    
    return jsonDictionary;
}

@end
