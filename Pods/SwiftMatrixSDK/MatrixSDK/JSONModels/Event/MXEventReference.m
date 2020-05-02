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

#import "MXEventReference.h"

@implementation MXEventReference

- (instancetype)initWithEventId:(NSString *)eventId type:(NSString *)type
{
    self = [super init];
    if (self)
    {
        _eventId = eventId;
        _type = type;
    }

    return self;
}

+ (instancetype)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXEventReference *eventReference;

    NSString *eventId, *type;
    MXJSONModelSetString(eventId, JSONDictionary[@"event_id"]);
    MXJSONModelSetString(type, JSONDictionary[@"type"]);

    if (eventId)
    {
        eventReference = [MXEventReference new];
        eventReference->_eventId = eventId;
        eventReference->_type = type;
    }

    return eventReference;
}

- (NSDictionary *)JSONDictionary
{
    NSMutableDictionary *JSONDictionary = [NSMutableDictionary dictionary];
    if (JSONDictionary)
    {
        JSONDictionary[@"event_id"] = _eventId;
        if (_type)
        {
            JSONDictionary[@"type"] = _type;
        }
    }

    return JSONDictionary;
}


#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self)
    {
        _eventId = [aDecoder decodeObjectForKey:@"event_id"];
        _type = [aDecoder decodeObjectForKey:@"type"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:_eventId forKey:@"event_id"];
    [aCoder encodeObject:_type forKey:@"type"];
}

@end
