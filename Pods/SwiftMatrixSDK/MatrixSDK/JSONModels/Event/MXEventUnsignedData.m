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

#import "MXEventUnsignedData.h"

#import "MXEvent.h"
#import "MXEventRelations.h"


@implementation MXEventUnsignedData


#pragma mark - MXJSONModel

+ (id)modelFromJSON:(NSDictionary *)JSONDictionary
{
    MXEventUnsignedData *unsignedData = [MXEventUnsignedData new];
    if (unsignedData)
    {
        if (JSONDictionary[@"age"])
        {
            MXJSONModelSetUInteger(unsignedData.age, JSONDictionary[@"age"]);
        }

        MXJSONModelSetString(unsignedData->_replacesState, JSONDictionary[@"replaces_state"]);
        MXJSONModelSetString(unsignedData->_prevSender, JSONDictionary[@"prev_sender"]);
        MXJSONModelSetDictionary(unsignedData->_prevContent, JSONDictionary[@"prev_content"]);
        MXJSONModelSetDictionary(unsignedData->_redactedBecause, JSONDictionary[@"redacted_because"]);
        MXJSONModelSetString(unsignedData->_transactionId, JSONDictionary[@"transaction_id"]);
        MXJSONModelSetDictionary(unsignedData->_inviteRoomState, JSONDictionary[@"invite_room_state"]);
        MXJSONModelSetMXJSONModel(unsignedData->_relations, MXEventRelations, JSONDictionary[@"m.relations"]);
    }

    return unsignedData;
}

- (NSDictionary *)JSONDictionary
{
    NSMutableDictionary *JSONDictionary = [NSMutableDictionary dictionary];
    if (JSONDictionary)
    {
        if (_ageLocalTs != -1)
        {
            JSONDictionary[@"age"] = @(self.age);
        }
        if (_replacesState)
        {
            JSONDictionary[@"replaces_state"] = _replacesState;
        }
        if (_prevSender)
        {
            JSONDictionary[@"prev_sender"] = _prevSender;
        }
        if (_prevContent)
        {
            JSONDictionary[@"prev_content"] = _prevContent;
        }
        if (_redactedBecause)
        {
            JSONDictionary[@"redacted_because"] = _redactedBecause;
        }
        if (_transactionId)
        {
            JSONDictionary[@"transaction_id"] = _transactionId;
        }
        if (_inviteRoomState)
        {
            JSONDictionary[@"invite_room_state"] = _inviteRoomState;
        }
        if (_relations)
        {
            JSONDictionary[@"m.relations"] = _relations.JSONDictionary;
        }
    }

    return JSONDictionary;
}


#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self)
    {
        _ageLocalTs = (uint64_t)[aDecoder decodeInt64ForKey:@"ageLocalTs"];
        _replacesState = [aDecoder decodeObjectForKey:@"replacesState"];
        _prevSender = [aDecoder decodeObjectForKey:@"prevSender"];
        _prevContent = [aDecoder decodeObjectForKey:@"prevContent"];
        _redactedBecause = [aDecoder decodeObjectForKey:@"redactedBecause"];
        _transactionId = [aDecoder decodeObjectForKey:@"transactionId"];
        _inviteRoomState = [aDecoder decodeObjectForKey:@"inviteRoomState"];
        _relations = [aDecoder decodeObjectForKey:@"relations"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt64:(int64_t)_ageLocalTs forKey:@"ageLocalTs"];
    [aCoder encodeObject:_replacesState forKey:@"replacesState"];
    [aCoder encodeObject:_prevSender forKey:@"prevSender"];
    [aCoder encodeObject:_prevContent forKey:@"prevContent"];
    [aCoder encodeObject:_redactedBecause forKey:@"redactedBecause"];
    [aCoder encodeObject:_transactionId forKey:@"transactionId"];
    [aCoder encodeObject:_inviteRoomState forKey:@"inviteRoomState"];
    [aCoder encodeObject:_relations forKey:@"relations"];
 }


#pragma mark - Private methods

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _ageLocalTs = -1;
    }

    return self;
}

- (void)setAge:(NSUInteger)age
{
    // If the age has not been stored yet in local time stamp, do it now
    if (-1 == _ageLocalTs)
    {
        _ageLocalTs = [[NSDate date] timeIntervalSince1970] * 1000 - age;
    }
}

- (NSUInteger)age
{
    NSUInteger age = 0;
    if (-1 != _ageLocalTs)
    {
        age = [[NSDate date] timeIntervalSince1970] * 1000 - _ageLocalTs;
    }
    return age;
}

@end
