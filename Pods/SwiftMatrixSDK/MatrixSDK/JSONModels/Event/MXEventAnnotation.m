/*
 Copyright 2019 New Vector Ltd

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

#import "MXEventAnnotation.h"


#pragma mark - Constants
NSString *const MXEventAnnotationReaction = @"m.reaction";


@implementation MXEventAnnotation

+ (instancetype)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXEventAnnotation *chunk;

    NSString *type, *key;
    MXJSONModelSetString(type, JSONDictionary[@"type"]);
    MXJSONModelSetString(key, JSONDictionary[@"key"]);
    if (type && key)
    {
        chunk = [MXEventAnnotation new];
        chunk->_type = type;
        chunk->_key = key;

        MXJSONModelSetInteger(chunk->_count, JSONDictionary[@"count"])
    }

    return chunk;
}

- (NSDictionary *)JSONDictionary
{
    NSMutableDictionary *JSONDictionary = [NSMutableDictionary dictionary];
    if (JSONDictionary)
    {
        JSONDictionary[@"type"] = _type;
        JSONDictionary[@"key"] = _key;
        JSONDictionary[@"count"] = @(_count);
    }

    return JSONDictionary;
}


#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self)
    {
        _type = [aDecoder decodeObjectForKey:@"type"];
        _key = [aDecoder decodeObjectForKey:@"key"];
        _count = [aDecoder decodeIntegerForKey:@"count"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:_type forKey:@"type"];
    [aCoder encodeObject:_key forKey:@"key"];
    [aCoder encodeInteger:_count forKey:@"count"];
}

@end
