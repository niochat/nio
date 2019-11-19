/*
 Copyright 2016 OpenMarket Ltd
 Copyright 2018 New Vector Ltd
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

#import "MXRoomEventFilter.h"

#import "MXJSONModel.h"

@implementation MXRoomEventFilter

- (void)setContainsURL:(BOOL)containsURL
{
    dictionary[@"contains_url"] = @(containsURL);
}

- (BOOL)containsURL
{
    BOOL containsURL = NO;
    MXJSONModelSetBoolean(containsURL, dictionary[@"contains_url"]);
    return containsURL;
}


- (void)setTypes:(NSArray<NSString *> *)types
{
    dictionary[@"types"] = types;
}

- (NSArray<NSString *> *)types
{
    NSArray<NSString *> *types;
    MXJSONModelSetArray(types, dictionary[@"types"]);
    return types;
}


- (void)setNotTypes:(NSArray<NSString *> *)notTypes
{
    dictionary[@"not_types"] = notTypes;
}

- (NSArray<NSString *> *)notTypes
{
    NSArray<NSString *> *notTypes;
    MXJSONModelSetArray(notTypes, dictionary[@"not_types"]);
    return notTypes;
}


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


- (void)setSenders:(NSArray<NSString *> *)senders
{
    dictionary[@"senders"] = senders;
}

- (NSArray<NSString *> *)senders
{
    NSArray<NSString *> *senders;
    MXJSONModelSetArray(senders, dictionary[@"senders"]);
    return senders;
}


- (void)setNotSenders:(NSArray<NSString *> *)notSenders
{
    dictionary[@"not_senders"] = notSenders;
}

-(NSArray<NSString *> *)notSenders
{
    NSArray<NSString *> *notSenders;
    MXJSONModelSetArray(notSenders, dictionary[@"not_senders"]);
    return notSenders;
}


- (void)setLimit:(NSUInteger)limit
{
    dictionary[@"limit"] = @(limit);
}

- (NSUInteger)limit
{
    NSUInteger limit = 10;  // Basic default value used by homeservers
    MXJSONModelSetUInteger(limit, dictionary[@"limit"]);
    return limit;
}


- (void)setLazyLoadMembers:(BOOL)lazyLoadMembers
{
    dictionary[@"lazy_load_members"] = @(lazyLoadMembers);
}

- (BOOL)lazyLoadMembers
{
    BOOL lazyLoadMembers = NO; // Basic default value used by homeservers
    MXJSONModelSetBoolean(lazyLoadMembers, dictionary[@"lazy_load_members"]);
    return lazyLoadMembers;
}


#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    return [[MXRoomEventFilter alloc] initWithDictionary:self.dictionary];
}

@end
