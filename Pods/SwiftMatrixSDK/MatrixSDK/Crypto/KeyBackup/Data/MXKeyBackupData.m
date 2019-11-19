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

#import "MXKeyBackupData.h"

@implementation MXKeyBackupData

#pragma mark - MXJSONModel

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXKeyBackupData *keyBackupData = [[MXKeyBackupData alloc] init];
    if (keyBackupData)
    {
        MXJSONModelSetInteger(keyBackupData.firstMessageIndex, JSONDictionary[@"first_message_index"]);
        MXJSONModelSetInteger(keyBackupData.forwardedCount, JSONDictionary[@"forwarded_count"]);
        MXJSONModelSetBoolean(keyBackupData.verified, JSONDictionary[@"is_verified"]);
        MXJSONModelSetDictionary(keyBackupData.sessionData, JSONDictionary[@"session_data"]);
    }
    return keyBackupData;
}

- (NSDictionary *)JSONDictionary
{
    NSMutableDictionary *JSONDictionary = [NSMutableDictionary dictionary];

    JSONDictionary[@"first_message_index"] = @(_firstMessageIndex);
    JSONDictionary[@"forwarded_count"] = @(_forwardedCount);
    JSONDictionary[@"is_verified"] = @(_verified);
    JSONDictionary[@"session_data"] = _sessionData;

    return JSONDictionary;
}

@end


@implementation MXRoomKeysBackupData

#pragma mark - MXJSONModel

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXRoomKeysBackupData *roomKeysBackupData = [[MXRoomKeysBackupData alloc] init];
    if (roomKeysBackupData)
    {
        NSDictionary *sessions;
        MXJSONModelSetDictionary(sessions, JSONDictionary[@"sessions"]);

        if (sessions)
        {
            NSMutableDictionary *mutableSessions = [[NSMutableDictionary alloc] initWithCapacity:sessions.count];
            for (NSString *sessionId in sessions)
            {
                MXKeyBackupData *keyBackupData;
                MXJSONModelSetMXJSONModel(keyBackupData, MXKeyBackupData, sessions[sessionId]);
                if (keyBackupData)
                {
                    mutableSessions[sessionId] = keyBackupData;
                }
            }
            roomKeysBackupData.sessions = mutableSessions;
        }
    }
    return roomKeysBackupData;
}

- (NSDictionary *)JSONDictionary
{
    NSMutableDictionary *sessions = [NSMutableDictionary dictionary];

    for (NSString *sessionId in _sessions)
    {
        sessions[sessionId] = _sessions[sessionId].JSONDictionary;
    }

    return @{
             @"sessions" : sessions
             };
}

@end


@implementation MXKeysBackupData

#pragma mark - MXJSONModel

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXKeysBackupData *keysBackupData = [[MXKeysBackupData alloc] init];
    if (keysBackupData)
    {
        NSDictionary *rooms;
        MXJSONModelSetDictionary(rooms, JSONDictionary[@"rooms"]);

        if (rooms)
        {
            NSMutableDictionary *mutableRooms = [[NSMutableDictionary alloc] initWithCapacity:rooms.count];
            for (NSString *roomId in rooms)
            {
                MXRoomKeysBackupData *roomKeysBackupData;
                MXJSONModelSetMXJSONModel(roomKeysBackupData, MXRoomKeysBackupData, rooms[roomId]);
                if (roomKeysBackupData)
                {
                    mutableRooms[roomId] = roomKeysBackupData;
                }
            }
            keysBackupData.rooms = mutableRooms;
        }
    }
    return keysBackupData;
}

- (NSDictionary *)JSONDictionary
{
    NSMutableDictionary *rooms = [NSMutableDictionary dictionary];

    for (NSString *roomId in _rooms)
    {
        rooms[roomId] = _rooms[roomId].JSONDictionary;
    }

    return @{
             @"rooms" : rooms
             };
}

@end
