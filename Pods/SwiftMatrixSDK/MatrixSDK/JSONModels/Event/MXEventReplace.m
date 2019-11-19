/*
 Copyright 2019 The Matrix.org Foundation C.I.C
 
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

#import "MXEventReplace.h"

static NSString* const kJSONReplacementEventId = @"event_id";
static NSString* const kCoderReplacementEventId = @"eventId";

@implementation MXEventReplace

+ (instancetype)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXEventReplace *eventReplace;
    
    if (JSONDictionary && JSONDictionary[kJSONReplacementEventId])
    {
        eventReplace = [MXEventReplace new];
        
        MXJSONModelSetString(eventReplace->_eventId, JSONDictionary[kJSONReplacementEventId])
    }
    
    return eventReplace;
}

- (NSDictionary *)JSONDictionary
{
    NSMutableDictionary *JSONDictionary = [NSMutableDictionary dictionary];
    
    JSONDictionary[kJSONReplacementEventId] = _eventId;
    
    return JSONDictionary;
}


#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self)
    {
        _eventId = [aDecoder decodeObjectForKey:kCoderReplacementEventId];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:_eventId forKey:kCoderReplacementEventId];
}

@end
