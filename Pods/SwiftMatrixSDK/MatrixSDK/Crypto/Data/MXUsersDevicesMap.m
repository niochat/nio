/*
 Copyright 2016 OpenMarket Ltd

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

#import "MXUsersDevicesMap.h"

@implementation MXUsersDevicesMap

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _map = [NSDictionary dictionary];
    }

    return self;
}

- (instancetype)initWithMap:(NSDictionary *)map
{
    self = [super init];
    if (self)
    {
        _map = map;
    }

    return self;
}

- (NSUInteger)count
{
    NSUInteger count = 0;

    for (NSString *userId in _map)
    {
        count += _map[userId].count;
    }

    return count;
}

- (NSArray<NSString *> *)userIds
{
    return _map.allKeys;
}

- (NSArray<NSString *> *)deviceIdsForUser:(NSString *)userId
{
    return _map[userId].allKeys;
}

-(id)objectForDevice:(NSString *)deviceId forUser:(NSString *)userId
{
    return _map[userId][deviceId];
}

- (NSArray<id>*)objectsForUser:(NSString*)userId
{
    return _map[userId].allValues;
}

- (NSArray<id>*)allObjects
{
    NSMutableArray *objects = [NSMutableArray array];

    for (NSString *userId in _map)
    {
        [objects addObjectsFromArray:_map[userId].allValues];
    }

    return objects;
}


- (void)setObject:(id)object forUser:(NSString *)userId andDevice:(NSString *)deviceId
{
    NSMutableDictionary *mutableMap = [NSMutableDictionary dictionaryWithDictionary:self.map];

    mutableMap[userId] = [NSMutableDictionary dictionaryWithDictionary:mutableMap[userId]];
    mutableMap[userId][deviceId] = object;

    _map = mutableMap;
}

-(void)setObjects:(NSDictionary *)objectsPerDevices forUser:(NSString *)userId
{
    NSMutableDictionary *mutableMap = [NSMutableDictionary dictionaryWithDictionary:_map];
    mutableMap[userId] = objectsPerDevices;

    _map = mutableMap;
}

- (void)addEntriesFromMap:(MXUsersDevicesMap*)map
{
    NSMutableDictionary *mutableMap = [NSMutableDictionary dictionaryWithDictionary:_map];
    [mutableMap addEntriesFromDictionary:map.map];

    _map = mutableMap;
}

- (void)removeAllObjects
{
    _map = @{};
}

- (void)removeObjectsForUser:(NSString *)userId
{
    NSMutableDictionary *mutableMap = [NSMutableDictionary dictionaryWithDictionary:_map];
    [mutableMap removeObjectForKey:userId];

    _map = mutableMap;
}

- (void)removeObjectForUser:(NSString *)userId andDevice:(NSString *)deviceId
{
    NSMutableDictionary *mutableMap = [NSMutableDictionary dictionaryWithDictionary:self.map];

    mutableMap[userId] = [NSMutableDictionary dictionaryWithDictionary:mutableMap[userId]];
    [mutableMap[userId] removeObjectForKey:deviceId];

    _map = mutableMap;
}

- (NSString *)description
{
    return _map.description;
}


#pragma mark - NSCoding
- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self)
    {
        _map = [aDecoder decodeObjectForKey:@"map"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:_map forKey:@"map"];
}

#pragma mark - NSCopying
- (id)copyWithZone:(NSZone *)zone
{
    MXUsersDevicesMap *usersDevicesMapCopy = [[MXUsersDevicesMap allocWithZone:zone] init];

    for (NSString *userId in _map)
    {
        for (NSString *deviceId in _map[userId])
        {
            id objectCopy = [_map[userId][deviceId] copy];
            [usersDevicesMapCopy setObject:objectCopy forUser:userId andDevice:deviceId];
        }
    }

    return usersDevicesMapCopy;
}

@end
