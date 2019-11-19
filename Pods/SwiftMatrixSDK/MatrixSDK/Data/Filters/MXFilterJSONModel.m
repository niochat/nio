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

#import "MXFilterJSONModel.h"

@implementation MXFilterJSONModel

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXFilterJSONModel *filter = [[MXFilterJSONModel alloc] init];
    if (filter)
    {
        NSDictionary *presenceFilter, *accountDataFilter, *roomFilter;

        MXJSONModelSetArray(filter.eventFields, JSONDictionary[@"event_fields"]);
        MXJSONModelSetString(filter.eventFormat, JSONDictionary[@"event_format"]);

        MXJSONModelSetDictionary(presenceFilter, JSONDictionary[@"presence"]);
        if (presenceFilter)
        {
            filter.presence = [[MXFilter alloc] initWithDictionary:presenceFilter];
        }

        MXJSONModelSetDictionary(accountDataFilter, JSONDictionary[@"account_data"]);
        if (accountDataFilter)
        {
            filter.accountData = [[MXFilter alloc] initWithDictionary:accountDataFilter];
        }

        MXJSONModelSetDictionary(roomFilter, JSONDictionary[@"room"]);
        if (roomFilter)
        {
            filter.room = [[MXRoomFilter alloc] initWithDictionary:roomFilter];
        }
    }

    return filter;
}

- (NSDictionary *)JSONDictionary
{
    NSMutableDictionary *JSONDictionary = [NSMutableDictionary dictionary];

    if (_eventFields)
    {
        JSONDictionary[@"event_fields"] = _eventFields;
    }
    if (_eventFormat)
    {
        JSONDictionary[@"event_format"] = _eventFormat;
    }
    if (_presence)
    {
        JSONDictionary[@"presence"] = _presence.dictionary;
    }
    if (_accountData)
    {
        JSONDictionary[@"account_data"] = _accountData.dictionary;
    }
    if (_room)
    {
        JSONDictionary[@"room"] = _room.dictionary;
    }

    return JSONDictionary;
}

- (BOOL)isEqual:(id)object
{
    if (self == object)
    {
        return YES;
    }

    BOOL isEqual = NO;

    if ([object isKindOfClass:MXFilterJSONModel.class])
    {
        MXFilterJSONModel *other = object;
        isEqual = [self.JSONDictionary isEqualToDictionary:other.JSONDictionary];
    }

    return isEqual;
}


#pragma mark - Factory

+ (MXFilterJSONModel*)syncFilterWithMessageLimit:(NSUInteger)messageLimit
{
    MXFilterJSONModel *filter = [[MXFilterJSONModel alloc] init];

    filter.room = [[MXRoomFilter alloc] init];
    filter.room.timeline = [[MXRoomEventFilter alloc] init];
    filter.room.timeline.limit = messageLimit;

    return filter;
}

+ (MXFilterJSONModel*)syncFilterForLazyLoading
{
    MXFilterJSONModel *filter = [[MXFilterJSONModel alloc] init];

    filter.room = [[MXRoomFilter alloc] init];
    filter.room.state = [[MXRoomEventFilter alloc] init];
    filter.room.state.lazyLoadMembers = YES;

    return filter;
}

+ (MXFilterJSONModel*)syncFilterForLazyLoadingWithMessageLimit:(NSUInteger)messageLimit
{
    MXFilterJSONModel *filter = [[MXFilterJSONModel alloc] init];

    filter.room = [[MXRoomFilter alloc] init];
    filter.room.timeline = [[MXRoomEventFilter alloc] init];
    filter.room.timeline.limit = messageLimit;
    filter.room.state = [[MXRoomEventFilter alloc] init];
    filter.room.state.lazyLoadMembers = YES;

    return filter;
}


- (NSString *)description
{
    return self.JSONDictionary.description;
}

@end
