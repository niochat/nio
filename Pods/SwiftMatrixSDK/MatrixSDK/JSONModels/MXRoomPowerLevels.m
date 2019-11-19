/*
 Copyright 2014 OpenMarket Ltd

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

#import "MXRoomPowerLevels.h"

#import "MXTools.h"

@implementation MXRoomPowerLevels

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXRoomPowerLevels *roomPowerLevels = [[MXRoomPowerLevels alloc] init];
    if (roomPowerLevels)
    {
        MXJSONModelSetDictionary(roomPowerLevels.users, JSONDictionary[@"users"]);
        MXJSONModelSetInteger(roomPowerLevels.ban, JSONDictionary[@"ban"]);
        MXJSONModelSetInteger(roomPowerLevels.kick, JSONDictionary[@"kick"]);
        MXJSONModelSetInteger(roomPowerLevels.redact, JSONDictionary[@"redact"]);
        MXJSONModelSetInteger(roomPowerLevels.invite, JSONDictionary[@"invite"]);
        MXJSONModelSetDictionary(roomPowerLevels.notifications, JSONDictionary[@"notifications"]);
        MXJSONModelSetDictionary(roomPowerLevels.events, JSONDictionary[@"events"]);
        
        // Read here default value by supporting the legacy CamelCase keys
        if (JSONDictionary[@"users_default"])
        {
            MXJSONModelSetInteger(roomPowerLevels.usersDefault, JSONDictionary[@"users_default"]);
        }
        else if (JSONDictionary[@"usersDefault"])
        {
            MXJSONModelSetInteger(roomPowerLevels.usersDefault, JSONDictionary[@"usersDefault"]);
        }
        else
        {
            // It is assumed to be 0
            roomPowerLevels.usersDefault = 0;
        }
        
        if (JSONDictionary[@"events_default"])
        {
            MXJSONModelSetInteger(roomPowerLevels.eventsDefault, JSONDictionary[@"events_default"]);
        }
        else if (JSONDictionary[@"eventsDefault"])
        {
            MXJSONModelSetInteger(roomPowerLevels.eventsDefault, JSONDictionary[@"eventsDefault"]);
        }
        else
        {
            // It is assumed to be 0
            roomPowerLevels.eventsDefault = 0;
        }
        
        if (JSONDictionary[@"state_default"])
        {
            MXJSONModelSetInteger(roomPowerLevels.stateDefault, JSONDictionary[@"state_default"]);
        }
        else if (JSONDictionary[@"stateDefault"])
        {
            MXJSONModelSetInteger(roomPowerLevels.stateDefault, JSONDictionary[@"stateDefault"]);
        }
        else
        {
            // state_default defaults to 50 if there is a power level event but no states_default key.
            roomPowerLevels.stateDefault = 50;
        }
        
    }
    return roomPowerLevels;
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        // Filled default values as specified by the doc
        _usersDefault = 0;

        // If the room contains no power_levels event, the state_default is 0. The events_default is 0 in either of these cases.
        _eventsDefault = 0;
        _stateDefault = 0;
    }
    return self;
}

- (NSInteger)powerLevelOfUserWithUserID:(NSString *)userId
{
    // By default, use usersDefault
    NSInteger userPowerLevel = _usersDefault;

    NSNumber *powerLevel;
    MXJSONModelSetNumber(powerLevel, _users[userId]);
    if (powerLevel)
    {
        userPowerLevel = [powerLevel integerValue];
    }

    return userPowerLevel;
}

- (NSInteger)minimumPowerLevelForSendingEventAsMessage:(MXEventTypeString)eventTypeString
{
    NSInteger minimumPowerLevel;

    NSNumber *powerLevel = _events[eventTypeString];
    if (powerLevel)
    {
        minimumPowerLevel = [powerLevel integerValue];
    }

    // Use the default value for sending event as message
    else
    {
        minimumPowerLevel = _eventsDefault;
    }

    return minimumPowerLevel;
}


- (NSInteger)minimumPowerLevelForSendingEventAsStateEvent:(MXEventTypeString)eventTypeString
{
    NSInteger minimumPowerLevel;

    NSNumber *powerLevel;
    MXJSONModelSetNumber(powerLevel, _events[eventTypeString]);
    if (powerLevel)
    {
        minimumPowerLevel = [powerLevel integerValue];
    }
    else
    {
        // Use the default value for sending event as state event
        minimumPowerLevel = _stateDefault;
    }

    return minimumPowerLevel;
}

- (NSInteger)minimumPowerLevelForNotifications:(NSString *)key defaultPower:(NSInteger)defaultPower
{
    NSInteger minimumPowerLevel = defaultPower;
    if (_notifications)
    {
        NSNumber *powerLevel;
        MXJSONModelSetNumber(powerLevel, _notifications[key]);
        if (powerLevel)
        {
            minimumPowerLevel = [powerLevel integerValue];
        }
    }

    return minimumPowerLevel;
}

- (NSDictionary *)JSONDictionary
{
    NSMutableDictionary *JSONDictionary = [NSMutableDictionary dictionary];

    JSONDictionary[@"users"] = _users;
    JSONDictionary[@"users_default"] = @(_usersDefault);
    JSONDictionary[@"ban"] = @(_ban);
    JSONDictionary[@"kick"] = @(_kick);
    JSONDictionary[@"redact"] = @(_redact);
    JSONDictionary[@"invite"] = @(_invite);
    JSONDictionary[@"notifications"] = _notifications;
    JSONDictionary[@"events"] = _events;
    JSONDictionary[@"events_default"] = @(_eventsDefault);
    JSONDictionary[@"state_default"] = @(_stateDefault);

    return JSONDictionary;
}

#pragma mark - NSCopying
- (id)copyWithZone:(NSZone *)zone
{
    MXRoomPowerLevels *roomPowerLevelsCopy = [[MXRoomPowerLevels allocWithZone:zone] init];

    roomPowerLevelsCopy.users = [_users copyWithZone:zone];
    roomPowerLevelsCopy.usersDefault = _usersDefault;
    roomPowerLevelsCopy.ban = _ban;
    roomPowerLevelsCopy.kick = _kick;
    roomPowerLevelsCopy.redact = _redact;
    roomPowerLevelsCopy.invite = _invite;
    roomPowerLevelsCopy.notifications = [_notifications copyWithZone:zone];
    roomPowerLevelsCopy.events = [_events copyWithZone:zone];
    roomPowerLevelsCopy.eventsDefault = _eventsDefault;
    roomPowerLevelsCopy.stateDefault = _stateDefault;

    return roomPowerLevelsCopy;
}

@end
