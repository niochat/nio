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

#import "MXEventAnnotationChunk.h"

#import "MXEventAnnotation.h"

@implementation MXEventAnnotationChunk

+ (instancetype)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXEventAnnotationChunk *annotationChunk;

    NSArray<MXEventAnnotation*> *annotations;
    MXJSONModelSetMXJSONModelArray(annotations, MXEventAnnotation, JSONDictionary[@"chunk"]);
    if (annotations)
    {
        annotationChunk = [MXEventAnnotationChunk new];
        annotationChunk->_chunk = annotations;

        MXJSONModelSetInteger(annotationChunk->_count, JSONDictionary[@"count"])
        MXJSONModelSetBoolean(annotationChunk->_limited, JSONDictionary[@"limited"])
    }

    return annotationChunk;
}

- (NSDictionary *)JSONDictionary
{
    NSMutableDictionary *JSONDictionary = [NSMutableDictionary dictionary];
    if (JSONDictionary)
    {
        NSMutableArray *annotations = [NSMutableArray arrayWithCapacity:_chunk.count];
        for (MXEventAnnotation *annotation in _chunk)
        {
            [annotations addObject:annotation.JSONDictionary];
        }
        JSONDictionary[@"chunk"] = annotations;

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
