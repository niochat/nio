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

#import "MXRoomFilter.h"

#import "MXJSONModel.h"

@implementation MXRoomFilter

- (void)setRooms:(NSArray<NSString *> *)rooms
{
    dictionary[@"rooms"] = rooms;
}

- (NSArray<NSString *> *)rooms
{
    NSArray<NSString *> *rooms;
    MXJSONModelSetArray(rooms, dictionary[@"rooms"]);
    return rooms;
}


- (void)setNotRooms:(NSArray<NSString *> *)notRooms
{
    dictionary[@"not_rooms"] = notRooms;
}

- (NSArray<NSString *> *)notRooms
{
    NSArray<NSString *> *notRooms;
    MXJSONModelSetArray(notRooms, dictionary[@"not_rooms"]);
    return notRooms;
}


- (void)setIncludeLeave:(BOOL)includeLeave
{
    dictionary[@"include_leave"] = @(includeLeave);
}

- (BOOL)includeLeave
{
    BOOL includeLeave = NO;
    MXJSONModelSetBoolean(includeLeave, dictionary[@"include_leave"]);
    return includeLeave;
}


#pragma mark - MXFilterObject override

- (instancetype)initWithDictionary:(NSDictionary *)dictionary
{
    NSMutableDictionary *flatDictionary = [dictionary mutableCopy];
    [flatDictionary removeObjectsForKeys:@[@"ephemeral", @"state", @"timeline", @"account_data"]];

    self = [super initWithDictionary:flatDictionary];
    if (self)
    {
        if (dictionary[@"ephemeral"])
        {
            _ephemeral = [[MXRoomEventFilter alloc] initWithDictionary:dictionary[@"ephemeral"]];
        }
        if (dictionary[@"state"])
        {
            _state = [[MXRoomEventFilter alloc] initWithDictionary:dictionary[@"state"]];
        }
        if (dictionary[@"timeline"])
        {
            _timeline = [[MXRoomEventFilter alloc] initWithDictionary:dictionary[@"timeline"]];
        }
        if (dictionary[@"account_data"])
        {
            _accountData = [[MXRoomEventFilter alloc] initWithDictionary:dictionary[@"account_data"]];
        }
    }
    return self;
}

- (NSDictionary<NSString *,id> *)dictionary
{
    NSMutableDictionary *flatDictionary = [super.dictionary mutableCopy];

    // And JSONify exposed models
    if (_ephemeral)
    {
        flatDictionary[@"ephemeral"] = _ephemeral.dictionary;
    }
    if (_state)
    {
        flatDictionary[@"state"] = _state.dictionary;
    }
    if (_timeline)
    {
        flatDictionary[@"timeline"] = _timeline.dictionary;
    }
    if (_accountData)
    {
        flatDictionary[@"account_data"] = _accountData.dictionary;
    }

    return flatDictionary;
}

@end
