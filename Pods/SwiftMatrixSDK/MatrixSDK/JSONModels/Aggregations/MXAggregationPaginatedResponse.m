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

#import "MXAggregationPaginatedResponse.h"
#import "MXAggregationPaginatedResponse_Private.h"

@implementation MXAggregationPaginatedResponse

- (instancetype)initWithOriginalEvent:(MXEvent*)originalEvent chunk:(NSArray<MXEvent*> *)chunk nextBatch:(NSString *)nextBatch;
{
    self = [super init];
    if (self)
    {
        _originalEvent = originalEvent;
        _chunk = chunk;
        _nextBatch = nextBatch;
    }
    return self;
}

+ (instancetype)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXAggregationPaginatedResponse *paginatedResponse;

    NSArray<MXEvent*> *chunk;
    MXJSONModelSetMXJSONModelArray(chunk, MXEvent.class, JSONDictionary[@"chunk"])

    if (chunk)
    {
        paginatedResponse = [MXAggregationPaginatedResponse new];

        paginatedResponse->_chunk = chunk;
        MXJSONModelSetString(paginatedResponse->_nextBatch, JSONDictionary[@"next_batch"])

        MXJSONModelSetMXJSONModel(paginatedResponse->_originalEvent, MXEvent.class, JSONDictionary[@"original_event"])
    }

    return paginatedResponse;
}

@end
