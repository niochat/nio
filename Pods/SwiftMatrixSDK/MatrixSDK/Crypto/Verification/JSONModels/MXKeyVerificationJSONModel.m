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

#import "MXKeyVerificationJSONModel.h"

#import "MXEvent.h"

@implementation MXKeyVerificationJSONModel

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    return [[self alloc] initWithJSONDictionary:JSONDictionary];
}

- (instancetype)initWithJSONDictionary:(NSDictionary *)JSONDictionary
{
    MXJSONModelSetString(_transactionId, JSONDictionary[@"transaction_id"]);
    MXJSONModelSetString(_relatedEventId, JSONDictionary[@"m.relates_to"][@"event_id"]);

    if (!_transactionId)
    {
        _transactionId = _relatedEventId;
    }

    // Sanitiy check
    if (!_transactionId.length)
    {
        return nil;
    }
    return self;
}

- (NSMutableDictionary*)JSONDictionaryWithTransactionId
{
    NSMutableDictionary *JSONDictionary = [NSMutableDictionary dictionary];

    if (_relatedEventId)
    {
        JSONDictionary[@"m.relates_to"] = @{
                                            @"event_id": _relatedEventId,
                                            @"rel_type": MXEventRelationTypeReference
                                            };
    }
    else
    {
        JSONDictionary[@"transaction_id"] = _transactionId;
    }

    return JSONDictionary;
}

@end
