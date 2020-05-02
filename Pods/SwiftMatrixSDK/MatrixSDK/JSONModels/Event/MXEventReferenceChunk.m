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

#import "MXEventReferenceChunk.h"

@implementation MXEventReferenceChunk

- (instancetype)initWithChunk:(NSArray<MXEventReference*> *)chunk count:(NSUInteger)count limited:(BOOL)limited
{
    self = [super init];
    if (self)
    {
        _chunk = chunk;
        _count = count;
        _limited = limited;
    }
    return self;
}

+ (instancetype)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXEventReferenceChunk *eventReferenceChunk;

    NSArray<MXEventReference*> *references;
    MXJSONModelSetMXJSONModelArray(references, MXEventReference, JSONDictionary[@"chunk"]);
    if (references)
    {
        eventReferenceChunk = [MXEventReferenceChunk new];
        eventReferenceChunk->_chunk = references;

        MXJSONModelSetInteger(eventReferenceChunk->_count, JSONDictionary[@"count"])
        MXJSONModelSetBoolean(eventReferenceChunk->_limited, JSONDictionary[@"limited"])
    }

    return eventReferenceChunk;
}

- (NSDictionary *)JSONDictionary
{
    NSMutableDictionary *JSONDictionary = [NSMutableDictionary dictionary];
    if (JSONDictionary)
    {
        NSMutableArray *references = [NSMutableArray arrayWithCapacity:_chunk.count];
        for (MXEventReference *reference in _chunk)
        {
            [references addObject:reference.JSONDictionary];
        }
        JSONDictionary[@"chunk"] = references;

        JSONDictionary[@"count"] = @(_count);
        JSONDictionary[@"limited"] = @(_limited);
    }

    return JSONDictionary;
}


#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self)
    {
        _chunk = [aDecoder decodeObjectForKey:@"chunk"];
        _count = [aDecoder decodeIntegerForKey:@"count"];
        _limited = [aDecoder decodeBoolForKey:@"limited"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:_chunk forKey:@"chunk"];
    [aCoder encodeInteger:_count forKey:@"count"];
    [aCoder encodeBool:_limited forKey:@"limited"];
}

@end
